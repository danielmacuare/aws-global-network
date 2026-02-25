from datetime import datetime

from rich.console import Console
from rich.panel import Panel
from rich.rule import Rule

# Module-level console singleton — thread-safe by default in Rich.
console = Console()


def _timestamp() -> str:
    return datetime.now().strftime("%H:%M:%S")


def log_info(msg: str) -> None:
    """Print an informational message with a blue [INFO] prefix."""
    console.print(f"[dim]{_timestamp()}[/dim] [bold blue]\\[INFO][/bold blue] {msg}")


def log_success(msg: str) -> None:
    """Print a success message with a green [SUCCESS] prefix."""
    console.print(
        f"[dim]{_timestamp()}[/dim] [bold green]\\[SUCCESS][/bold green] {msg}"
    )


def log_error(msg: str) -> None:
    """Print an error message with a red [ERROR] prefix."""
    console.print(f"[dim]{_timestamp()}[/dim] [bold red]\\[ERROR][/bold red] {msg}")


def log_warn(msg: str) -> None:
    """Print a warning message with a yellow [WARN] prefix."""
    console.print(
        f"[dim]{_timestamp()}[/dim] [bold yellow]\\[WARN][/bold yellow] {msg}"
    )


def log_phase(title: str) -> None:
    """Print a bold cyan rule separator marking the start of a new phase."""
    console.print()
    console.print(Rule(f"[bold cyan]{title}[/bold cyan]", style="cyan"))
    console.print()
