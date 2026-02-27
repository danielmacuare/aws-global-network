"""
phases.py — Phase orchestration: run_parallel_phase() and run_sequential_phase().

Each function wraps TerraformRunner execution for a list of Terraform directories,
either concurrently (parallel) or one at a time (sequential). Both functions log a
rich phase banner, collect TimingRecord results, and surface failures as a RuntimeError
listing all failed directories after printing individual errors.
"""

import time
from concurrent.futures import ThreadPoolExecutor, as_completed

from rich.console import Console
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    TextColumn,
    TimeElapsedColumn,
)

from lib.config import PhaseResult, RunConfig, TimingRecord
from lib.console import log_error, log_info, log_phase, log_warn
from lib.runner import TerraformError, TerraformRunner


def _make_runner(rel_dir: str, config: RunConfig, destroy: bool) -> TerraformRunner:
    """
    Construct a TerraformRunner for *rel_dir*.

    The existing TerraformRunner does not expose a ``destroy`` parameter — apply vs
    plan is governed by ``config.dry_run``.  When ``destroy=True``, we monkey-patch
    the runner instance so that ``_run_apply`` issues ``terraform destroy -auto-approve``
    instead of ``terraform apply -auto-approve``.
    """
    import subprocess

    runner = TerraformRunner(rel_dir, config)

    if destroy and not config.dry_run:
        # Override _run_apply to use terraform destroy.
        def _run_destroy(log_fh) -> int:
            result = subprocess.run(
                ["terraform", "destroy", "-auto-approve", "-input=false"],
                cwd=runner.abs_dir,
                stdout=log_fh,
                stderr=subprocess.STDOUT,
            )
            return result.returncode

        runner._run_apply = _run_destroy  # type: ignore[method-assign]

    return runner


def run_parallel_phase(
    phase_name: str,
    dirs: list[str],
    config: RunConfig,
    console: Console,
    destroy: bool = False,
) -> PhaseResult:
    """
    Run all *dirs* concurrently using :class:`~concurrent.futures.ThreadPoolExecutor`.

    Collects ALL failures before raising (not fail-fast) so the caller receives a
    complete picture of what went wrong.  Returns a :class:`~lib.config.PhaseResult`
    with per-directory timing records and the list of failed directories.

    Parameters
    ----------
    phase_name:
        Human-readable name shown in the phase banner and stored in PhaseResult.
    dirs:
        Relative directory paths (relative to ``config.repo_root``) to process.
    config:
        Active run configuration.
    console:
        Rich Console instance for thread-safe output.
    destroy:
        When True, each runner executes ``terraform destroy`` instead of ``terraform apply``.

    Raises
    ------
    RuntimeError
        If one or more directories fail.  All errors are printed before raising.
    """
    log_phase(phase_name)

    t_start = time.monotonic()

    if not dirs:
        log_warn(f"{phase_name}: no directories to process — skipping.")
        t_end = time.monotonic()
        return PhaseResult(
            phase_name=phase_name,
            t_start=t_start,
            t_end=t_end,
        )

    log_info(
        f"{phase_name}: processing {len(dirs)} director{'y' if len(dirs) == 1 else 'ies'} in parallel."
    )

    records: list[TimingRecord] = []
    failed_dirs: list[str] = []

    progress = Progress(
        TextColumn("[bold cyan]{task.description}"),
        BarColumn(bar_width=40),
        MofNCompleteColumn(),
        TimeElapsedColumn(),
        console=console,
    )

    with progress:
        task = progress.add_task(phase_name, total=len(dirs))

        with ThreadPoolExecutor(max_workers=config.parallelism) as executor:
            future_to_dir = {
                executor.submit(_make_runner(rel_dir, config, destroy).run): rel_dir
                for rel_dir in dirs
            }

            for future in as_completed(future_to_dir):
                rel_dir = future_to_dir[future]
                try:
                    record = future.result()
                    records.append(record)
                except TerraformError as exc:
                    log_error(
                        f"Phase '{phase_name}' — FAILED: {exc.rel_dir} (rc={exc.rc}). Log: {exc.log_file}"
                    )
                    failed_dirs.append(exc.rel_dir)
                except Exception as exc:
                    log_error(
                        f"Phase '{phase_name}' — unexpected error in {rel_dir}: {exc}"
                    )
                    failed_dirs.append(rel_dir)
                finally:
                    progress.advance(task)

    t_end = time.monotonic()

    result = PhaseResult(
        phase_name=phase_name,
        t_start=t_start,
        t_end=t_end,
        records=records,
        failed_dirs=failed_dirs,
    )

    if failed_dirs:
        raise RuntimeError(
            f"Phase '{phase_name}' completed with {len(failed_dirs)} failure(s): "
            + ", ".join(failed_dirs)
        )

    return result


def run_sequential_phase(
    phase_name: str,
    dirs: list[str],
    config: RunConfig,
    console: Console,
    destroy: bool = False,
) -> PhaseResult:
    """
    Run *dirs* one at a time, in order.

    Raises on the first failure (fail-fast).  Returns a
    :class:`~lib.config.PhaseResult` with per-directory timing records.

    Parameters
    ----------
    phase_name:
        Human-readable name shown in the phase banner and stored in PhaseResult.
    dirs:
        Relative directory paths (relative to ``config.repo_root``) to process.
    config:
        Active run configuration.
    console:
        Rich Console instance for output.
    destroy:
        When True, each runner executes ``terraform destroy`` instead of ``terraform apply``.

    Raises
    ------
    RuntimeError
        If a directory fails.
    """
    log_phase(phase_name)

    t_start = time.monotonic()

    if not dirs:
        log_warn(f"{phase_name}: no directories to process — skipping.")
        t_end = time.monotonic()
        return PhaseResult(
            phase_name=phase_name,
            t_start=t_start,
            t_end=t_end,
        )

    log_info(
        f"{phase_name}: processing {len(dirs)} director{'y' if len(dirs) == 1 else 'ies'} sequentially."
    )

    records: list[TimingRecord] = []

    progress = Progress(
        TextColumn("[bold cyan]{task.description}"),
        BarColumn(bar_width=40),
        MofNCompleteColumn(),
        TimeElapsedColumn(),
        console=console,
    )

    with progress:
        task = progress.add_task(phase_name, total=len(dirs))

        for rel_dir in dirs:
            try:
                runner = _make_runner(rel_dir, config, destroy)
                record = runner.run()
                records.append(record)
            except TerraformError as exc:
                log_error(
                    f"Phase '{phase_name}' — FAILED: {exc.rel_dir} (rc={exc.rc}). Log: {exc.log_file}"
                )
                t_end = time.monotonic()
                raise RuntimeError(
                    f"Phase '{phase_name}' failed in directory '{exc.rel_dir}' (rc={exc.rc})."
                ) from exc
            except Exception as exc:
                log_error(
                    f"Phase '{phase_name}' — unexpected error in {rel_dir}: {exc}"
                )
                t_end = time.monotonic()
                raise RuntimeError(
                    f"Phase '{phase_name}' encountered an unexpected error in '{rel_dir}': {exc}"
                ) from exc
            finally:
                progress.advance(task)

    t_end = time.monotonic()

    return PhaseResult(
        phase_name=phase_name,
        t_start=t_start,
        t_end=t_end,
        records=records,
        failed_dirs=[],
    )
