"""Tests for lib.phases — run_parallel_phase() and run_sequential_phase()."""

import sys
import time
from pathlib import Path
from unittest.mock import MagicMock, patch, call

sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
from rich.console import Console

from lib.config import PhaseResult, RunConfig, TimingRecord
from lib.phases import run_parallel_phase, run_sequential_phase
from lib.runner import TerraformError


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def make_config(tmp_path: Path, **kwargs) -> RunConfig:
    defaults = dict(
        environments=["dev"],
        regions=[],
        dry_run=False,
        skip_peering=False,
        force_peering=False,
        repo_root=tmp_path,
        log_dir=tmp_path / "logs",
        tgw_stabilise_wait=30,
        log_retention=10,
    )
    defaults.update(kwargs)
    (tmp_path / "logs").mkdir(parents=True, exist_ok=True)
    return RunConfig(**defaults)


def _make_fake_record(rel_dir: str) -> TimingRecord:
    t = time.monotonic()
    return TimingRecord(rel_dir=rel_dir, t_start=t, t_end=t + 1.0)


def _silent_console() -> Console:
    """Return a Console that writes to /dev/null."""
    from io import StringIO
    return Console(file=StringIO(), highlight=False)


# ---------------------------------------------------------------------------
# run_parallel_phase
# ---------------------------------------------------------------------------


class TestRunParallelPhase:
    def test_parallel_phase_returns_phase_result(self, tmp_path: Path) -> None:
        """Returns a PhaseResult with the correct phase_name."""
        config = make_config(tmp_path)
        console = _silent_console()
        dirs = ["envs/dev/euw2/cell1000", "envs/dev/euw2/cell1001"]
        phase_name = "vpc-cells"

        fake_record = _make_fake_record("envs/dev/euw2/cell1000")

        mock_runner = MagicMock()
        mock_runner.run.return_value = fake_record

        with patch("lib.phases._make_runner", return_value=mock_runner):
            with patch("lib.phases.log_phase"):
                with patch("lib.phases.log_info"):
                    result = run_parallel_phase(phase_name, dirs, config, console)

        assert isinstance(result, PhaseResult)
        assert result.phase_name == phase_name
        assert result.failed_dirs == []

    def test_parallel_phase_collects_all_failures(self, tmp_path: Path) -> None:
        """When multiple runners fail, all failed dirs are collected before raising."""
        config = make_config(tmp_path)
        console = _silent_console()
        dirs = ["envs/dev/euw2/cell1000", "envs/dev/euw2/cell1001", "envs/dev/euw2/cell1002"]
        phase_name = "vpc-cells"

        log_file = tmp_path / "logs" / "test.log"

        call_count = 0

        def make_runner_side_effect(rel_dir, cfg, destroy):
            runner = MagicMock()
            nonlocal call_count
            call_count += 1
            if rel_dir in ("envs/dev/euw2/cell1001", "envs/dev/euw2/cell1002"):
                runner.run.side_effect = TerraformError(rel_dir, 1, log_file)
            else:
                runner.run.return_value = _make_fake_record(rel_dir)
            return runner

        with patch("lib.phases._make_runner", side_effect=make_runner_side_effect):
            with patch("lib.phases.log_phase"):
                with patch("lib.phases.log_info"):
                    with patch("lib.phases.log_error"):
                        with pytest.raises(RuntimeError) as exc_info:
                            run_parallel_phase(phase_name, dirs, config, console)

        assert "envs/dev/euw2/cell1001" in str(exc_info.value) or "envs/dev/euw2/cell1002" in str(exc_info.value)

    def test_parallel_phase_raises_on_any_failure(self, tmp_path: Path) -> None:
        """RuntimeError is raised when at least one runner fails."""
        config = make_config(tmp_path)
        console = _silent_console()
        dirs = ["envs/dev/euw2/cell1000"]
        log_file = tmp_path / "logs" / "test.log"

        mock_runner = MagicMock()
        mock_runner.run.side_effect = TerraformError("envs/dev/euw2/cell1000", 1, log_file)

        with patch("lib.phases._make_runner", return_value=mock_runner):
            with patch("lib.phases.log_phase"):
                with patch("lib.phases.log_info"):
                    with patch("lib.phases.log_error"):
                        with pytest.raises(RuntimeError):
                            run_parallel_phase(phase_name="vpc-cells", dirs=dirs, config=config, console=console)

    def test_empty_dirs_returns_empty_phase_result(self, tmp_path: Path) -> None:
        """Returns an empty PhaseResult with no records when dirs is empty."""
        config = make_config(tmp_path)
        console = _silent_console()

        with patch("lib.phases.log_phase"):
            with patch("lib.phases.log_warn"):
                result = run_parallel_phase("vpc-cells", [], config, console)

        assert isinstance(result, PhaseResult)
        assert result.phase_name == "vpc-cells"
        assert result.records == []
        assert result.failed_dirs == []


# ---------------------------------------------------------------------------
# run_sequential_phase
# ---------------------------------------------------------------------------


class TestRunSequentialPhase:
    def test_sequential_phase_runs_in_order(self, tmp_path: Path) -> None:
        """Runners are called in the order dirs are provided."""
        config = make_config(tmp_path)
        console = _silent_console()
        dirs = ["envs/dev/euw2/cell1000", "envs/dev/euw2/cell1001", "envs/dev/euw2/cell1002"]
        phase_name = "vpc-cells"

        call_order: list[str] = []

        def make_runner_side_effect(rel_dir, cfg, destroy):
            runner = MagicMock()
            def run_and_record():
                call_order.append(rel_dir)
                return _make_fake_record(rel_dir)
            runner.run.side_effect = run_and_record
            return runner

        with patch("lib.phases._make_runner", side_effect=make_runner_side_effect):
            with patch("lib.phases.log_phase"):
                with patch("lib.phases.log_info"):
                    result = run_sequential_phase(phase_name, dirs, config, console)

        assert call_order == dirs
        assert isinstance(result, PhaseResult)
        assert result.phase_name == phase_name

    def test_sequential_phase_returns_phase_result(self, tmp_path: Path) -> None:
        """Returns a PhaseResult with timing records for each dir."""
        config = make_config(tmp_path)
        console = _silent_console()
        dirs = ["envs/dev/euw2/cell1000"]
        phase_name = "tgw"

        mock_runner = MagicMock()
        mock_runner.run.return_value = _make_fake_record("envs/dev/euw2/cell1000")

        with patch("lib.phases._make_runner", return_value=mock_runner):
            with patch("lib.phases.log_phase"):
                with patch("lib.phases.log_info"):
                    result = run_sequential_phase(phase_name, dirs, config, console)

        assert isinstance(result, PhaseResult)
        assert result.phase_name == phase_name
        assert len(result.records) == 1
        assert result.failed_dirs == []

    def test_sequential_phase_raises_on_first_failure(self, tmp_path: Path) -> None:
        """Sequential phase stops at the first failure (fail-fast)."""
        config = make_config(tmp_path)
        console = _silent_console()
        dirs = ["envs/dev/euw2/cell1000", "envs/dev/euw2/cell1001"]
        log_file = tmp_path / "logs" / "test.log"

        call_order: list[str] = []

        def make_runner_side_effect(rel_dir, cfg, destroy):
            runner = MagicMock()
            if rel_dir == "envs/dev/euw2/cell1000":
                runner.run.side_effect = TerraformError(rel_dir, 1, log_file)
            else:
                def run_and_record():
                    call_order.append(rel_dir)
                    return _make_fake_record(rel_dir)
                runner.run.side_effect = run_and_record
            return runner

        with patch("lib.phases._make_runner", side_effect=make_runner_side_effect):
            with patch("lib.phases.log_phase"):
                with patch("lib.phases.log_info"):
                    with patch("lib.phases.log_error"):
                        with pytest.raises(RuntimeError):
                            run_sequential_phase("vpc-cells", dirs, config, console)

        # The second dir should never have been called
        assert "envs/dev/euw2/cell1001" not in call_order

    def test_empty_dirs_returns_empty_phase_result(self, tmp_path: Path) -> None:
        """Returns an empty PhaseResult with no records when dirs is empty."""
        config = make_config(tmp_path)
        console = _silent_console()

        with patch("lib.phases.log_phase"):
            with patch("lib.phases.log_warn"):
                result = run_sequential_phase("tgw", [], config, console)

        assert isinstance(result, PhaseResult)
        assert result.phase_name == "tgw"
        assert result.records == []
        assert result.failed_dirs == []
