"""
runner.py — TerraformRunner: runs terraform init + apply/plan in a directory.
"""

import subprocess
import time
from pathlib import Path

from lib.config import RunConfig, TimingRecord
from lib.console import log_error, log_info, log_success, log_warn


class TerraformError(Exception):
    """Raised when a terraform command exits non-zero."""

    def __init__(self, rel_dir: str, rc: int, log_file: Path) -> None:
        self.rel_dir = rel_dir
        self.rc = rc
        self.log_file = log_file
        super().__init__(f"Terraform failed in {rel_dir} (rc={rc}). See {log_file}")


class TerraformRunner:
    """
    Encapsulates a single terraform init + apply (or plan) execution.

    Parameters
    ----------
    rel_dir:
        Path relative to *config.repo_root*, e.g. ``'envs/dev/euw2/cell1000'``.
    config:
        The active :class:`~lib.config.RunConfig`.
    """

    def __init__(self, rel_dir: str, config: RunConfig) -> None:
        self.rel_dir = rel_dir
        self.config = config
        self.abs_dir: Path = config.repo_root / rel_dir
        # Use '-' as separator to avoid tr '_' '/' confusion from the old bash scripts.
        log_name = rel_dir.replace("/", "-") + ".log"
        self.log_file: Path = config.log_dir / log_name

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def run(self) -> TimingRecord:
        """
        Execute ``terraform init -upgrade`` then ``apply`` or ``plan``.

        Behaviour
        ---------
        * If no ``.tf`` files are found in ``self.abs_dir`` a warning is logged
          and a zero-duration :class:`~lib.config.TimingRecord` is returned.
        * ``terraform init -upgrade -input=false`` stdout+stderr are always
          captured to the log file.
        * **dry_run=True**: ``terraform plan -input=false`` output is streamed
          to the terminal *and* appended to the log file.
        * **dry_run=False**: ``terraform apply -auto-approve -input=false``
          stdout+stderr are captured to the log file only.
        * :class:`TerraformError` is raised on any non-zero return code.

        Returns
        -------
        TimingRecord
            Timing information for this directory.
        """
        t_start = time.monotonic()

        if not any(self.abs_dir.glob("*.tf")):
            log_warn(f"Skipping {self.rel_dir} — no .tf files found")
            return TimingRecord(rel_dir=self.rel_dir, t_start=t_start, t_end=t_start)

        if self.config.dry_run:
            log_info(f"Planning : {self.rel_dir}")
        else:
            log_info(f"Deploying: {self.rel_dir}")

        with self.log_file.open("ab") as lf:
            # ── terraform init ────────────────────────────────────────────────
            init_result = subprocess.run(
                ["terraform", "init", "-upgrade", "-input=false"],
                cwd=self.abs_dir,
                stdout=lf,
                stderr=subprocess.STDOUT,
            )
            if init_result.returncode != 0:
                t_end = time.monotonic()
                log_error(f"FAILED (init): {self.rel_dir} — see {self.log_file}")
                raise TerraformError(self.rel_dir, init_result.returncode, self.log_file)

            # ── terraform plan / apply ────────────────────────────────────────
            if self.config.dry_run:
                rc = self._run_plan(lf)
            else:
                rc = self._run_apply(lf)

        t_end = time.monotonic()

        if rc != 0:
            log_error(f"FAILED: {self.rel_dir} — see {self.log_file}")
            raise TerraformError(self.rel_dir, rc, self.log_file)

        duration = t_end - t_start
        log_success(f"Done: {self.rel_dir} ({duration:.1f}s)")
        return TimingRecord(rel_dir=self.rel_dir, t_start=t_start, t_end=t_end)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _run_plan(self, log_fh) -> int:
        """
        Run ``terraform plan`` streaming output to the terminal and log file.

        Uses ``subprocess.PIPE`` to capture stdout+stderr, then writes each
        chunk to both ``sys.stdout`` (via print) and the open log file handle.
        """
        proc = subprocess.Popen(
            ["terraform", "plan", "-input=false"],
            cwd=self.abs_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        assert proc.stdout is not None  # guaranteed by stdout=PIPE
        for chunk in proc.stdout:
            print(chunk.decode(errors="replace"), end="", flush=True)
            log_fh.write(chunk)
        proc.wait()
        return proc.returncode

    def _run_apply(self, log_fh) -> int:
        """
        Run ``terraform apply -auto-approve`` capturing all output to the log file only.
        """
        result = subprocess.run(
            ["terraform", "apply", "-auto-approve", "-input=false"],
            cwd=self.abs_dir,
            stdout=log_fh,
            stderr=subprocess.STDOUT,
        )
        return result.returncode
