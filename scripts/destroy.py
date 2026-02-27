#!/usr/bin/env python3
"""Destroy AWS Global Network infrastructure in reverse phase order."""

import sys

if sys.version_info < (3, 11):
    print(f"ERROR: Python 3.11+ required (current: {sys.version})", file=sys.stderr)
    sys.exit(1)

import shutil
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

import typer
from typing_extensions import Annotated

# Add scripts/ dir to path so 'lib' package is importable.
sys.path.insert(0, str(Path(__file__).parent))

from lib.config import RunConfig
from lib.console import console, log_info, log_success, log_warn
from lib.discovery import (
    discover_keypairs,
    discover_tgw_peering,
    discover_tgw_vpc_atts,
    discover_tgws,
    discover_vpc_cells,
)
from lib.phases import run_parallel_phase, run_sequential_phase
from lib.timing import TimingSummary

app = typer.Typer(
    help="Destroy AWS Global Network infrastructure in reverse phase order."
)


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
        typer.Option("--dry-run", help="Run terraform plan only, no changes applied"),
    ] = False,
    skip_peering: Annotated[
        bool,
        typer.Option("--skip-peering", help="Skip TGW Peering teardown phase"),
    ] = False,
    force_peering: Annotated[
        bool,
        typer.Option(
            "--force-peering",
            help="Bypass TGW Peering readiness gate (unused in destroy, kept for interface parity)",
        ),
    ] = False,
    tgw_wait: Annotated[
        int,
        typer.Option(
            "--tgw-wait",
            help="Seconds to wait for TGW stabilisation between Phase 2 and 3",
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
) -> None:
    """Destroy all AWS Global Network infrastructure in reverse dependency order."""
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
        f"Destroy started: environments={config.environments}, "
        f"regions={config.regions or 'all'}, dry_run={dry_run}"
    )
    log_info(f"Log directory: {log_dir}")

    # Discovery
    keypairs = discover_keypairs(config)
    vpc_cells = discover_vpc_cells(config)
    tgws = discover_tgws(config)
    tgw_atts = discover_tgw_vpc_atts(config)
    tgw_peering = discover_tgw_peering(config)

    log_info(
        f"Discovered: {len(keypairs)} keypair(s), {len(vpc_cells)} VPC cell(s), "
        f"{len(tgws)} TGW(s), {len(tgw_atts)} TGW-VPC att(s), {len(tgw_peering)} peering dir(s)"
    )

    timing = TimingSummary()

    # Phase 1: TGW Peering teardown (sequential)
    if skip_peering:
        log_warn("--skip-peering flag set: skipping TGW Peering teardown phase.")
    else:
        try:
            result = run_sequential_phase(
                "Phase 1: TGW Peering Teardown",
                tgw_peering,
                config,
                console,
                destroy=True,
            )
            timing.add_phase(result)
        except RuntimeError as exc:
            from lib.console import log_error

            log_error(str(exc))
            sys.exit(1)

    # Phase 2: TGW-VPC Attachments teardown (parallel)
    try:
        result = run_parallel_phase(
            "Phase 2: TGW-VPC Attachments Teardown",
            tgw_atts,
            config,
            console,
            destroy=True,
        )
        timing.add_phase(result)
    except RuntimeError as exc:
        from lib.console import log_error

        log_error(str(exc))
        sys.exit(1)

    # Wait: TGW stabilisation (allow detachments to propagate before destroying TGWs)
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

    # Phase 3: TGWs + VPCs teardown (parallel, combined)
    phase3_dirs = tgws + vpc_cells
    try:
        result = run_parallel_phase(
            "Phase 3: TGWs + VPCs Teardown",
            phase3_dirs,
            config,
            console,
            destroy=True,
        )
        timing.add_phase(result)
    except RuntimeError as exc:
        from lib.console import log_error

        log_error(str(exc))
        sys.exit(1)

    # Phase 4: SSH Key Pairs teardown (parallel)
    try:
        result = run_parallel_phase(
            "Phase 4: SSH Key Pairs Teardown",
            keypairs,
            config,
            console,
            destroy=True,
        )
        timing.add_phase(result)
    except RuntimeError as exc:
        from lib.console import log_error

        log_error(str(exc))
        sys.exit(1)

    # Timing summary
    timing.render(console)
    log_success("Destroy complete.")


if __name__ == "__main__":
    app()
