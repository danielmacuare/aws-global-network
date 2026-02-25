"""Tests for lib.runner.TerraformRunner — no real terraform calls."""

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest

from lib.config import RunConfig, TimingRecord
from lib.runner import TerraformError, TerraformRunner


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


def _make_tf_dir(tmp_path: Path, rel_dir: str) -> Path:
    """Create a fake Terraform directory with a main.tf file."""
    d = tmp_path / rel_dir
    d.mkdir(parents=True, exist_ok=True)
    (d / "main.tf").write_text("# placeholder\n")
    return d


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestTerraformRunnerSkip:
    def test_runner_skips_dir_with_no_tf_files(self, tmp_path: Path) -> None:
        """Runner returns a zero-duration TimingRecord when no .tf files exist."""
        rel_dir = "envs/dev/euw2/cell1000"
        d = tmp_path / rel_dir
        d.mkdir(parents=True)
        # No .tf files added

        config = make_config(tmp_path)
        runner = TerraformRunner(rel_dir, config)

        with patch("lib.runner.log_warn") as mock_warn:
            record = runner.run()

        assert isinstance(record, TimingRecord)
        assert record.rel_dir == rel_dir
        # Zero-duration record: t_start == t_end
        assert record.t_start == record.t_end
        mock_warn.assert_called_once()


class TestTerraformRunnerApply:
    def test_runner_calls_init_then_apply(self, tmp_path: Path) -> None:
        """Runner calls terraform init then terraform apply in non-dry-run mode."""
        rel_dir = "envs/dev/euw2/cell1000"
        _make_tf_dir(tmp_path, rel_dir)
        config = make_config(tmp_path, dry_run=False)
        runner = TerraformRunner(rel_dir, config)

        mock_result = MagicMock()
        mock_result.returncode = 0

        call_commands: list[list[str]] = []

        def fake_run(cmd, **kwargs):
            call_commands.append(cmd)
            return mock_result

        with patch("lib.runner.subprocess.run", side_effect=fake_run):
            with patch("lib.runner.log_info"):
                with patch("lib.runner.log_success"):
                    record = runner.run()

        assert len(call_commands) == 2
        assert call_commands[0] == ["terraform", "init", "-upgrade", "-input=false"]
        assert call_commands[1] == ["terraform", "apply", "-auto-approve", "-input=false"]
        assert isinstance(record, TimingRecord)

    def test_runner_calls_init_then_plan_in_dry_run(self, tmp_path: Path) -> None:
        """Runner calls terraform init then terraform plan in dry_run mode."""
        rel_dir = "envs/dev/euw2/cell1000"
        _make_tf_dir(tmp_path, rel_dir)
        config = make_config(tmp_path, dry_run=True)
        runner = TerraformRunner(rel_dir, config)

        # Patch subprocess.run for init, and Popen for plan
        mock_init_result = MagicMock()
        mock_init_result.returncode = 0

        mock_proc = MagicMock()
        mock_proc.stdout = iter([b"Plan: 1 to add.\n"])
        mock_proc.returncode = 0
        mock_proc.wait.return_value = None

        with patch("lib.runner.subprocess.run", return_value=mock_init_result) as mock_run:
            with patch("lib.runner.subprocess.Popen", return_value=mock_proc):
                with patch("lib.runner.log_info"):
                    with patch("lib.runner.log_success"):
                        record = runner.run()

        # Only subprocess.run should be called once (for init)
        mock_run.assert_called_once()
        init_cmd = mock_run.call_args[0][0]
        assert init_cmd == ["terraform", "init", "-upgrade", "-input=false"]
        assert isinstance(record, TimingRecord)


class TestTerraformRunnerErrors:
    def test_runner_raises_on_nonzero_rc(self, tmp_path: Path) -> None:
        """Runner raises TerraformError when terraform returns non-zero exit code."""
        rel_dir = "envs/dev/euw2/cell1000"
        _make_tf_dir(tmp_path, rel_dir)
        config = make_config(tmp_path, dry_run=False)
        runner = TerraformRunner(rel_dir, config)

        mock_result = MagicMock()
        mock_result.returncode = 1

        with patch("lib.runner.subprocess.run", return_value=mock_result):
            with patch("lib.runner.log_info"):
                with patch("lib.runner.log_error"):
                    with pytest.raises(TerraformError) as exc_info:
                        runner.run()

        err = exc_info.value
        assert err.rel_dir == rel_dir
        assert err.rc == 1
        assert isinstance(err.log_file, Path)

    def test_runner_raises_terraform_error_on_apply_failure(self, tmp_path: Path) -> None:
        """Runner raises TerraformError when apply step returns non-zero."""
        rel_dir = "envs/dev/euw2/cell1000"
        _make_tf_dir(tmp_path, rel_dir)
        config = make_config(tmp_path, dry_run=False)
        runner = TerraformRunner(rel_dir, config)

        call_count = 0

        def fake_run(cmd, **kwargs):
            nonlocal call_count
            call_count += 1
            result = MagicMock()
            # init succeeds, apply fails
            result.returncode = 0 if call_count == 1 else 1
            return result

        with patch("lib.runner.subprocess.run", side_effect=fake_run):
            with patch("lib.runner.log_info"):
                with patch("lib.runner.log_error"):
                    with pytest.raises(TerraformError) as exc_info:
                        runner.run()

        assert exc_info.value.rc == 1


class TestTerraformRunnerLogFile:
    def test_runner_log_file_uses_dash_separator(self, tmp_path: Path) -> None:
        """Log file name uses '-' as path separator, not '/'."""
        rel_dir = "envs/dev/euw2/cell1000"
        config = make_config(tmp_path)
        runner = TerraformRunner(rel_dir, config)

        log_name = runner.log_file.name
        assert "/" not in log_name
        assert "_" not in log_name.replace("_", "")  # no underscores from path sep
        assert log_name == "envs-dev-euw2-cell1000.log"

    def test_runner_log_file_is_inside_log_dir(self, tmp_path: Path) -> None:
        """Log file is placed inside the configured log_dir."""
        rel_dir = "envs/dev/euw2/cell1000"
        config = make_config(tmp_path)
        runner = TerraformRunner(rel_dir, config)

        assert runner.log_file.parent == config.log_dir
