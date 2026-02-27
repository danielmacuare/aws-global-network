#!/usr/bin/env python3
"""Deploy AWS Global Network infrastructure in parallel."""

import sys

if sys.version_info < (3, 11):
    print(f"ERROR: Python 3.11+ required (current: {sys.version})", file=sys.stderr)
    sys.exit(1)

import shutil
import subprocess
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

import typer
from typing_extensions import Annotated

# Add scripts/ dir to path so 'lib' package is importable.
sys.path.insert(0, str(Path(__file__).parent))

from lib.config import RunConfig
from lib.console import console, log_info, log_phase, log_success, log_warn
from lib.discovery import (
    discover_keypairs,
    discover_tgw_peering,
    discover_tgw_vpc_atts,
    discover_tgws,
    discover_vpc_cells,
)
from lib.peering_gate import PeeringGate
from lib.phases import run_parallel_phase, run_sequential_phase
from lib.timing import TimingSummary

app = typer.Typer(help="Deploy AWS Global Network infrastructure in parallel.")


def _parse_environment(environment: str) -> list[str]:
    """Convert the --environment option into a list of environment names."""
    if environment == "all":
        return ["dev", "prod"]
    if environment in ("dev", "prod"):
        return [environment]
    typer.echo(
        f"ERROR: --environment must be one of: dev, prod, all (got: {environment!r})",
        err=True,
    )
    raise typer.Exit(1)


def _parse_regions(regions: Optional[str]) -> list[str]:
    """Convert the --regions option into a list of region short-names."""
    if not regions:
        return []
    return [r.strip() for r in regions.split(",") if r.strip()]


def _rotate_logs(logs_base: Path, retention: int) -> None:
    """Keep only the *retention* newest log run directories, deleting older ones."""
    if not logs_base.exists():
        return
    dirs = sorted(logs_base.iterdir())
    while len(dirs) > retention:
        shutil.rmtree(dirs.pop(0))


def _print_instance_inventory(
    vpc_cells: list[str],
    config: RunConfig,
    *,
    write_json: bool = False,
    refresh: bool = False,
) -> None:
    """
    For each VPC cell directory, run ``terraform output -json instances`` and
    display results in a Rich table.

    Parameters
    ----------
    write_json:
        When True, write ``instances.json`` to the repo root.
    refresh:
        When True, run ``terraform refresh`` on each cell before collecting
        outputs to ensure IPs are up-to-date with AWS.
    """
    import json

    from rich.table import Table

    any_printed = False
    inventory: dict[str, dict] = {}

    for rel_dir in vpc_cells:
        abs_dir = config.repo_root / rel_dir
        if not abs_dir.is_dir():
            continue

        # Optionally refresh state from AWS before reading outputs
        if refresh:
            log_info(f"Refreshing state: {rel_dir}")
            try:
                subprocess.run(
                    [
                        "terraform",
                        "apply",
                        "-refresh-only",
                        "-auto-approve",
                        "-input=false",
                    ],
                    cwd=abs_dir,
                    capture_output=True,
                    text=True,
                    timeout=120,
                )
            except (subprocess.TimeoutExpired, FileNotFoundError):
                log_warn(
                    f"Refresh timed out or failed for {rel_dir}, using cached state."
                )

        try:
            result = subprocess.run(
                ["terraform", "output", "-json", "instances"],
                cwd=abs_dir,
                capture_output=True,
                text=True,
                timeout=30,
            )
        except (subprocess.TimeoutExpired, FileNotFoundError):
            continue

        if result.returncode != 0 or not result.stdout.strip():
            continue

        try:
            instances = json.loads(result.stdout)
        except json.JSONDecodeError:
            continue

        if not instances:
            continue

        # Build a flat list of rows from the nested bastions / private_hosts structure.
        rows: list[tuple[str, str, str]] = []
        cell_data: dict[str, dict[str, str]] = {
            "bastions": {},
            "private_hosts": {},
        }

        if isinstance(instances, dict):
            bastions = instances.get("bastions", {})
            private_hosts = instances.get("private_hosts", {})

            if isinstance(bastions, dict):
                for name, ip in sorted(bastions.items()):
                    rows.append((str(name), str(ip), "bastion"))
                    cell_data["bastions"][str(name)] = str(ip)
            if isinstance(private_hosts, dict):
                for name, ip in sorted(private_hosts.items()):
                    rows.append((str(name), str(ip), "private"))
                    cell_data["private_hosts"][str(name)] = str(ip)

            # Fallback: if no bastions/private_hosts keys, treat as flat { name: attrs }
            if not rows:
                for name, attrs in instances.items():
                    if isinstance(attrs, dict):
                        ip = str(attrs.get("private_ip", attrs.get("ip", "—")))
                        rows.append((str(name), ip, str(attrs.get("type", "—"))))
                        cell_data["private_hosts"][str(name)] = ip
                    elif isinstance(attrs, str):
                        rows.append((str(name), str(attrs), "—"))
                        cell_data["private_hosts"][str(name)] = str(attrs)

        if not rows:
            continue

        inventory[rel_dir] = cell_data

        table = Table(
            title=f"Instances: {rel_dir}",
            show_header=True,
            header_style="bold green",
        )
        table.add_column("Name")
        table.add_column("IP")
        table.add_column("Type")

        for name, ip, inst_type in rows:
            table.add_row(name, ip, inst_type)

        console.print(table)
        any_printed = True

    if not any_printed:
        log_info("No instance inventory output found across VPC cells.")

    # Write machine-readable JSON inventory to repo root
    if write_json:
        inventory_file = config.repo_root / "instances.json"
        inventory_file.write_text(json.dumps(inventory, indent=2) + "\n")
        log_info(f"Instance inventory written to {inventory_file}")


@app.command()
def main(
    environment: Annotated[
        str,
        typer.Option("--environment", "-e", help="dev | prod | all"),
    ] = "all",
    regions: Annotated[
        Optional[str],
        typer.Option(
            "--regions",
            "-r",
            help="Comma-separated regions, e.g. euw2,euw1 (default: all)",
        ),
    ] = None,
    dry_run: Annotated[
        bool,
        typer.Option("--dry-run", help="Run terraform plan only — no changes applied"),
    ] = False,
    skip_peering: Annotated[
        bool,
        typer.Option("--skip-peering", help="Skip TGW Peering Attachment phase"),
    ] = False,
    force_peering: Annotated[
        bool,
        typer.Option("--force-peering", help="Bypass TGW Peering readiness gate"),
    ] = False,
    tgw_wait: Annotated[
        int,
        typer.Option(
            "--tgw-wait",
            help="Seconds to wait for TGW stabilisation between Phase 1 and 2",
        ),
    ] = 30,
    parallelism: Annotated[
        int,
        typer.Option(
            "--parallelism",
            "-p",
            help="Max concurrent terraform runs (default: 8)",
        ),
    ] = 8,
    json_output: Annotated[
        bool,
        typer.Option(
            "--json",
            help="Write instances.json to repo root after deploy",
        ),
    ] = False,
    json_only: Annotated[
        bool,
        typer.Option(
            "--json-only",
            help="Skip deploy, collect terraform outputs and write instances.json",
        ),
    ] = False,
    json_refresh: Annotated[
        bool,
        typer.Option(
            "--json-refresh",
            help="Skip deploy, refresh state from AWS, then write instances.json",
        ),
    ] = False,
) -> None:
    """Deploy all AWS Global Network infrastructure."""
    repo_root = Path(__file__).parent.parent
    logs_base = repo_root / "logs"
    log_dir = logs_base / datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
    log_dir.mkdir(parents=True, exist_ok=True)

    config = RunConfig(
        environments=_parse_environment(environment),
        regions=_parse_regions(regions),
        dry_run=dry_run,
        skip_peering=skip_peering,
        force_peering=force_peering,
        repo_root=repo_root,
        log_dir=log_dir,
        tgw_stabilise_wait=tgw_wait,
        parallelism=parallelism,
    )

    _rotate_logs(logs_base, config.log_retention)

    log_info(
        f"Deploy started — environments={config.environments}, regions={config.regions or 'all'}, "
        f"dry_run={dry_run}, parallelism={config.parallelism}"
    )
    log_info(f"Log directory: {log_dir}")

    # Discovery
    keypairs = discover_keypairs(config)
    vpc_cells = discover_vpc_cells(config)
    tgws = discover_tgws(config)
    tgw_atts = discover_tgw_vpc_atts(config)
    tgw_peering = discover_tgw_peering(config)

    log_info(
        f"Discovered: {len(keypairs)} keypair(s), {len(vpc_cells)} VPC cell(s), {len(tgws)} TGW(s), {len(tgw_atts)} TGW-VPC att(s), {len(tgw_peering)} peering dir(s)"
    )

    # --json-only / --json-refresh: skip all deploy phases, just collect outputs
    if json_only or json_refresh:
        log_phase("Instance Inventory (json-only mode)")
        _print_instance_inventory(
            vpc_cells,
            config,
            write_json=True,
            refresh=json_refresh,
        )
        return

    timing = TimingSummary()

    # Phase 0: SSH Key Pairs (parallel)
    try:
        result = run_parallel_phase("Phase 0: SSH Key Pairs", keypairs, config, console)
        timing.add_phase(result)
    except RuntimeError as exc:
        from lib.console import log_error

        log_error(str(exc))
        sys.exit(1)

    # Phase 1: VPCs + TGWs (parallel, combined)
    phase1_dirs = tgws + vpc_cells
    try:
        result = run_parallel_phase(
            "Phase 1: VPCs + TGWs", phase1_dirs, config, console
        )
        timing.add_phase(result)
    except RuntimeError as exc:
        from lib.console import log_error

        log_error(str(exc))
        sys.exit(1)

    # Wait — TGW stabilisation
    if not dry_run and config.tgw_stabilise_wait > 0:
        log_info(f"Waiting {config.tgw_stabilise_wait}s for TGW stabilisation...")
        from rich.progress import Progress, SpinnerColumn, TimeElapsedColumn

        with Progress(
            SpinnerColumn(),
            "[progress.description]{task.description}",
            TimeElapsedColumn(),
            console=console,
        ) as progress:
            task = progress.add_task(
                f"TGW stabilisation ({config.tgw_stabilise_wait}s)...",
                total=config.tgw_stabilise_wait,
            )
            elapsed = 0
            while elapsed < config.tgw_stabilise_wait:
                time.sleep(1)
                elapsed += 1
                progress.advance(task, 1)
    elif dry_run:
        log_info(
            f"Dry-run mode: skipping {config.tgw_stabilise_wait}s TGW stabilisation wait."
        )

    # Phase 2: TGW-VPC Attachments (parallel)
    try:
        result = run_parallel_phase(
            "Phase 2: TGW-VPC Attachments", tgw_atts, config, console
        )
        timing.add_phase(result)
    except RuntimeError as exc:
        from lib.console import log_error

        log_error(str(exc))
        sys.exit(1)

    # Phase 3: TGW Peering (sequential, guarded by PeeringGate)
    if skip_peering:
        log_warn("--skip-peering flag set: skipping TGW Peering phase.")
    else:
        gate = PeeringGate(config, tgw_peering)
        all_ready, readiness_results = gate.check()
        gate.render_status(readiness_results, console)

        if not all_ready:
            log_warn(
                "TGW Peering readiness gate: not all regions ready. Skipping Phase 3 (non-fatal)."
            )
            log_warn(
                "Re-run once all TGWs have been applied, or use --force-peering to bypass."
            )
            timing.render(console)
            sys.exit(0)

        try:
            result = run_sequential_phase(
                "Phase 3: TGW Peering", tgw_peering, config, console
            )
            timing.add_phase(result)
        except RuntimeError as exc:
            from lib.console import log_error

            log_error(str(exc))
            timing.render(console)
            sys.exit(1)

    # Instance inventory
    if not dry_run:
        log_phase("Instance Inventory")
        _print_instance_inventory(
            vpc_cells,
            config,
            write_json=json_output or json_only or json_refresh,
            refresh=json_refresh,
        )

    # Timing summary
    timing.render(console)
    log_success("Deploy complete.")


if __name__ == "__main__":
    app()
