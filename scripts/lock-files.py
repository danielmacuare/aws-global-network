#!/usr/bin/env python3
"""Update .terraform.lock.hcl files for all target platforms in parallel."""

import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path

if sys.version_info < (3, 11):
    print(f"ERROR: Python 3.11+ required (current: {sys.version})", file=sys.stderr)
    sys.exit(1)

import typer
from rich.progress import BarColumn, MofNCompleteColumn, Progress, TextColumn, TimeElapsedColumn
from rich.rule import Rule
from rich.table import Table

sys.path.insert(0, str(Path(__file__).parent))
from lib.console import console

REPO_ROOT = Path(__file__).resolve().parent.parent
TF_SEARCH_DIRS = ["bootstrap", "envs", "modules"]

DEFAULT_PLATFORMS = [
    "linux_amd64",
    "linux_arm64",
    "darwin_amd64",
    "darwin_arm64",
    "windows_amd64",
]

app = typer.Typer(help="Regenerate .terraform.lock.hcl files for all target platforms.")


@dataclass
class LockResult:
    rel_dir: str
    passed: bool
    duration: float
    output: str


def _find_tf_dirs() -> list[str]:
    """Return sorted list of relative dirs (from repo root) that contain .tf files."""
    dirs: set[str] = set()
    for base in TF_SEARCH_DIRS:
        base_path = REPO_ROOT / base
        if not base_path.exists():
            continue
        for tf_file in base_path.rglob("*.tf"):
            if ".terraform" not in tf_file.parts:
                dirs.add(str(tf_file.parent.relative_to(REPO_ROOT)))
    return sorted(dirs)


def _lock(rel_dir: str, platforms: list[str]) -> LockResult:
    abs_dir = REPO_ROOT / rel_dir
    platform_flags = []
    for p in platforms:
        platform_flags += ["-platform", p]

    t_start = time.monotonic()
    result = subprocess.run(
        ["terraform", "providers", "lock", "-no-color", *platform_flags],
        cwd=abs_dir,
        capture_output=True,
        text=True,
    )
    duration = time.monotonic() - t_start
    output = (result.stdout + result.stderr).strip()
    return LockResult(
        rel_dir=rel_dir,
        passed=result.returncode == 0,
        duration=duration,
        output=output,
    )


def _fmt_duration(seconds: float) -> str:
    total = int(seconds)
    minutes, secs = divmod(total, 60)
    if minutes:
        return f"{minutes}m {secs}s"
    return f"{secs}s"


@app.command()
def main(
    parallelism: int = typer.Option(
        os.cpu_count() or 8,
        "--parallelism", "-p",
        help="Number of parallel workers.",
    ),
    platforms: list[str] = typer.Option(
        DEFAULT_PLATFORMS,
        "--platform",
        help="Target platform (can be specified multiple times). "
             "Defaults to linux_amd64, linux_arm64, darwin_amd64, darwin_arm64, windows_amd64.",
    ),
) -> None:
    tf_dirs = _find_tf_dirs()

    console.print()
    console.print(Rule("[bold cyan]Terraform Lock File Update[/bold cyan]", style="cyan"))
    console.print(
        f"[dim]Found [bold]{len(tf_dirs)}[/bold] Terraform directories — "
        f"running with [bold]{parallelism}[/bold] workers[/dim]"
    )
    console.print(f"[dim]Platforms: [bold]{', '.join(platforms)}[/bold][/dim]")
    console.print()

    results: list[LockResult] = []
    t_wall_start = time.monotonic()

    progress = Progress(
        TextColumn("[bold cyan]{task.description}"),
        BarColumn(bar_width=40),
        MofNCompleteColumn(),
        TimeElapsedColumn(),
        console=console,
    )

    with progress:
        task = progress.add_task("locking", total=len(tf_dirs))
        with ThreadPoolExecutor(max_workers=parallelism) as executor:
            futures = {executor.submit(_lock, d, platforms): d for d in tf_dirs}
            for future in as_completed(futures):
                results.append(future.result())
                progress.advance(task)

    t_wall = time.monotonic() - t_wall_start

    # Sort results: failures first, then alphabetically
    results.sort(key=lambda r: (r.passed, r.rel_dir))

    table = Table(
        title="Lock File Results",
        show_header=True,
        header_style="bold magenta",
        show_lines=False,
    )
    table.add_column("Directory", style="dim", no_wrap=True)
    table.add_column("Status", justify="center", width=10)
    table.add_column("Duration", justify="right", width=10)
    table.add_column("Output", no_wrap=False)

    for r in results:
        status = "[bold green]PASS[/bold green]" if r.passed else "[bold red]FAIL[/bold red]"
        output_cell = ""
        if not r.passed:
            first_error = next(
                (line for line in r.output.splitlines() if line.strip()),
                r.output[:120],
            )
            output_cell = f"[red]{first_error}[/red]"
        table.add_row(r.rel_dir, status, _fmt_duration(r.duration), output_cell)

    table.add_section()
    passed = sum(1 for r in results if r.passed)
    failed = len(results) - passed
    table.add_row(
        f"[bold magenta]Total: {len(results)} dirs[/bold magenta]",
        f"[bold green]{passed} passed[/bold green]  [bold red]{failed} failed[/bold red]",
        f"[bold magenta]{_fmt_duration(t_wall)} wall[/bold magenta]",
        "",
    )

    console.print()
    console.print(table)

    failures = [r for r in results if not r.passed]
    if failures:
        console.print()
        console.print(Rule("[bold red]Failure Details[/bold red]", style="red"))
        for r in failures:
            console.print(f"\n[bold red]FAIL:[/bold red] [bold]{r.rel_dir}[/bold]")
            console.print(f"[red]{r.output}[/red]")

    sys.exit(0 if not failures else 1)


if __name__ == "__main__":
    app()
