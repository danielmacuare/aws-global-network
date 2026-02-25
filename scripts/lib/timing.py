# All timing measurements use time.monotonic() to avoid wall-clock drift
# and to ensure correct elapsed calculations across DST transitions or NTP adjustments.

from rich.console import Console
from rich.table import Table

from lib.config import PhaseResult


def _fmt_duration(seconds: float) -> str:
    """Format a duration in seconds as a human-readable string, e.g. '2m 34s' or '45s'."""
    total = int(seconds)
    minutes, secs = divmod(total, 60)
    if minutes:
        return f"{minutes}m {secs}s"
    return f"{secs}s"


class TimingSummary:
    """Collects PhaseResult objects and renders a summary table via Rich."""

    def __init__(self) -> None:
        self._phases: list[PhaseResult] = []

    def add_phase(self, result: PhaseResult) -> None:
        """Append a completed PhaseResult to the summary."""
        self._phases.append(result)

    def render(self, console: Console) -> None:
        """
        Print two sets of tables to the given console:

        1. A top-level summary table — one row per phase showing total duration,
           plus a total row at the bottom.
        2. For each phase, a per-directory breakdown table showing individual durations.
        """
        if not self._phases:
            console.print("[dim]No timing data to display.[/dim]")
            return

        # --- Top-level phase summary ---
        summary_table = Table(
            title="Phase Summary", show_header=True, header_style="bold magenta"
        )
        summary_table.add_column("Phase", style="bold")
        summary_table.add_column("Duration", justify="right")

        total_duration = 0.0
        for phase in self._phases:
            duration = phase.t_end - phase.t_start
            total_duration += duration
            summary_table.add_row(phase.phase_name, _fmt_duration(duration))

        summary_table.add_section()
        summary_table.add_row(
            "[bold magenta]Total[/bold magenta]",
            f"[bold magenta]{_fmt_duration(total_duration)}[/bold magenta]",
        )

        console.print(summary_table)

        # --- Per-phase directory breakdown ---
        for phase in self._phases:
            if not phase.records:
                continue

            breakdown_table = Table(
                title=f"{phase.phase_name} — Directory Breakdown",
                show_header=True,
                header_style="bold cyan",
            )
            breakdown_table.add_column("Directory", style="dim")
            breakdown_table.add_column("Duration", justify="right")

            for record in phase.records:
                duration = record.t_end - record.t_start
                breakdown_table.add_row(record.rel_dir, _fmt_duration(duration))

            console.print(breakdown_table)
