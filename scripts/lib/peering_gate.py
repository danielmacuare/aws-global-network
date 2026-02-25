#!/usr/bin/env python3
"""TGW Peering Readiness Gate — checks all required TGWs are applied before peering."""

import json
import re
import subprocess
from pathlib import Path

from pydantic import BaseModel
from rich.console import Console
from rich.table import Table

from lib.config import RunConfig
from lib.console import log_info, log_warn


class RegionReadiness(BaseModel):
    """Readiness status for a single TGW region."""

    region_short: str
    tgw_dir: str
    is_ready: bool
    reason: str  # e.g. "TGW ID: tgw-0abc1234" or "No state output found"


class PeeringGate:
    """
    Checks that all TGWs referenced by the peering directories have been applied
    (i.e. have a non-empty transit_gateway output) before allowing peering to proceed.
    """

    def __init__(self, config: RunConfig, peering_dirs: list[str]) -> None:
        self.config = config
        self.peering_dirs = peering_dirs

    def _extract_tgw_dirs(self) -> list[str]:
        """
        Reads data.tf in each peering_dir and extracts terraform_remote_state
        key attributes matching '*-tgw*'. Returns deduped list of TGW relative dirs.

        Uses regex: r'key\\s*=\\s*"([^"]*-tgw[^"]*)"'
        Then converts the key (e.g. "env-networking/euw2-tgw/terraform.tfstate")
        to a relative dir path (e.g. "envs/networking/euw2/tgw").
        """
        key_pattern = re.compile(r'key\s*=\s*"([^"]*-tgw[^"]*)"')
        region_pattern = re.compile(r"env-networking/([^/]+)-tgw/")

        tgw_dirs: list[str] = []
        seen: set[str] = set()

        for peering_dir in self.peering_dirs:
            data_tf = self.config.repo_root / peering_dir / "data.tf"
            if not data_tf.is_file():
                continue

            content = data_tf.read_text()
            for key_match in key_pattern.finditer(content):
                key = key_match.group(1)
                region_match = region_pattern.search(key)
                if not region_match:
                    continue
                region = region_match.group(1)
                tgw_dir = f"envs/networking/{region}/tgw"
                if tgw_dir not in seen:
                    seen.add(tgw_dir)
                    tgw_dirs.append(tgw_dir)

        return tgw_dirs

    def _check_tgw_ready(self, tgw_dir: str) -> RegionReadiness:
        """
        Runs: terraform -chdir=<abs_tgw_dir> output -json
        Checks output["transit_gateway"]["value"]["id"] is non-empty.
        Returns RegionReadiness.
        """
        abs_tgw_dir = self.config.repo_root / tgw_dir
        # Derive region_short from the directory path (e.g. "envs/networking/euw2/tgw" -> "euw2")
        parts = Path(tgw_dir).parts
        region_short = parts[-2] if len(parts) >= 2 else tgw_dir

        result = subprocess.run(
            ["terraform", "output", "-json"],
            cwd=str(abs_tgw_dir),
            capture_output=True,
            text=True,
        )

        if result.returncode != 0 or not result.stdout.strip():
            return RegionReadiness(
                region_short=region_short,
                tgw_dir=tgw_dir,
                is_ready=False,
                reason="No state output found",
            )

        try:
            outputs = json.loads(result.stdout)
        except json.JSONDecodeError:
            return RegionReadiness(
                region_short=region_short,
                tgw_dir=tgw_dir,
                is_ready=False,
                reason="Invalid JSON from terraform output",
            )

        tgw_value = outputs.get("transit_gateway", {}).get("value", {})
        tgw_id = tgw_value.get("id", "") if isinstance(tgw_value, dict) else ""

        if tgw_id:
            return RegionReadiness(
                region_short=region_short,
                tgw_dir=tgw_dir,
                is_ready=True,
                reason=f"TGW ID: {tgw_id}",
            )

        return RegionReadiness(
            region_short=region_short,
            tgw_dir=tgw_dir,
            is_ready=False,
            reason="No state output found",
        )

    def check(self) -> tuple[bool, list[RegionReadiness]]:
        """
        If config.force_peering: return (True, []) with a [WARN] message.
        Otherwise: check each TGW dir and return (all_ready, results).
        """
        if self.config.force_peering:
            log_warn("force_peering=True — skipping TGW readiness gate.")
            return (True, [])

        tgw_dirs = self._extract_tgw_dirs()

        if not tgw_dirs:
            log_info(
                "No TGW remote state references found in peering dirs — gate passed."
            )
            return (True, [])

        results: list[RegionReadiness] = []
        for tgw_dir in tgw_dirs:
            readiness = self._check_tgw_ready(tgw_dir)
            results.append(readiness)

        all_ready = all(r.is_ready for r in results)
        return (all_ready, results)

    def render_status(self, results: list[RegionReadiness], console: Console) -> None:
        """Prints a rich table: Region | TGW Dir | Ready | Reason.  Skips if no results."""
        if not results:
            return

        table = Table(title="TGW Peering Readiness")
        table.add_column("Region", style="cyan")
        table.add_column("TGW Dir", style="dim")
        table.add_column("Ready", justify="center")
        table.add_column("Reason")

        for r in results:
            ready_str = (
                "[bold green]YES[/bold green]"
                if r.is_ready
                else "[bold red]NO[/bold red]"
            )
            table.add_row(r.region_short, r.tgw_dir, ready_str, r.reason)

        console.print(table)
