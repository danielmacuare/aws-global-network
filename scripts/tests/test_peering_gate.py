"""Tests for lib.peering_gate.PeeringGate — no real terraform calls."""

import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest

from lib.config import RunConfig
from lib.peering_gate import PeeringGate, RegionReadiness


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
    return RunConfig(**defaults)


def _write_data_tf(path: Path, content: str) -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / "data.tf").write_text(content)


SAMPLE_DATA_TF = '''
data "terraform_remote_state" "tgw_euw2" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "env-networking/euw2-tgw/terraform.tfstate"
    region = "eu-west-2"
  }
}
'''

SAMPLE_DATA_TF_MULTI = '''
data "terraform_remote_state" "tgw_euw2" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "env-networking/euw2-tgw/terraform.tfstate"
    region = "eu-west-2"
  }
}

data "terraform_remote_state" "tgw_euw1" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "env-networking/euw1-tgw/terraform.tfstate"
    region = "eu-west-1"
  }
}
'''


# ---------------------------------------------------------------------------
# _extract_tgw_dirs
# ---------------------------------------------------------------------------


class TestExtractTgwDirs:
    def test_extract_tgw_dirs_parses_data_tf(self, tmp_path: Path) -> None:
        """Parses a single TGW key from data.tf and converts to relative dir path."""
        peering_dir = "envs/networking/global/tgw-peering"
        _write_data_tf(tmp_path / peering_dir, SAMPLE_DATA_TF)

        config = make_config(tmp_path)
        gate = PeeringGate(config, [peering_dir])
        result = gate._extract_tgw_dirs()

        assert result == ["envs/networking/euw2/tgw"]

    def test_extract_tgw_dirs_parses_multiple_keys(self, tmp_path: Path) -> None:
        """Parses multiple TGW keys and returns all unique dirs."""
        peering_dir = "envs/networking/global/tgw-peering"
        _write_data_tf(tmp_path / peering_dir, SAMPLE_DATA_TF_MULTI)

        config = make_config(tmp_path)
        gate = PeeringGate(config, [peering_dir])
        result = gate._extract_tgw_dirs()

        assert "envs/networking/euw2/tgw" in result
        assert "envs/networking/euw1/tgw" in result
        assert len(result) == 2

    def test_extract_tgw_dirs_deduplicates(self, tmp_path: Path) -> None:
        """Same key referenced in two peering_dirs yields only one entry."""
        peering_dir_a = "envs/networking/global/tgw-peering"
        peering_dir_b = "envs/networking/global/tgw-peering-b"
        _write_data_tf(tmp_path / peering_dir_a, SAMPLE_DATA_TF)
        _write_data_tf(tmp_path / peering_dir_b, SAMPLE_DATA_TF)

        config = make_config(tmp_path)
        gate = PeeringGate(config, [peering_dir_a, peering_dir_b])
        result = gate._extract_tgw_dirs()

        assert result.count("envs/networking/euw2/tgw") == 1

    def test_extract_tgw_dirs_returns_empty_when_no_data_tf(self, tmp_path: Path) -> None:
        """Returns empty list when peering_dirs have no data.tf."""
        config = make_config(tmp_path)
        gate = PeeringGate(config, ["envs/networking/global/tgw-peering"])
        result = gate._extract_tgw_dirs()
        assert result == []


# ---------------------------------------------------------------------------
# check() — readiness logic
# ---------------------------------------------------------------------------


class TestPeeringGateCheck:
    def test_check_returns_all_ready_when_tgw_output_present(self, tmp_path: Path) -> None:
        """Returns (True, results) when terraform output shows a valid TGW ID."""
        peering_dir = "envs/networking/global/tgw-peering"
        _write_data_tf(tmp_path / peering_dir, SAMPLE_DATA_TF)
        # Create the tgw dir so abs path exists
        (tmp_path / "envs" / "networking" / "euw2" / "tgw").mkdir(parents=True)

        valid_output = json.dumps({
            "transit_gateway": {
                "value": {"id": "tgw-0abc1234", "arn": "arn:aws:ec2:..."},
                "type": "object",
            }
        })

        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = valid_output

        config = make_config(tmp_path)
        gate = PeeringGate(config, [peering_dir])

        with patch("lib.peering_gate.subprocess.run", return_value=mock_result):
            all_ready, results = gate.check()

        assert all_ready is True
        assert len(results) == 1
        assert results[0].is_ready is True
        assert "tgw-0abc1234" in results[0].reason

    def test_check_returns_not_ready_when_tgw_output_empty(self, tmp_path: Path) -> None:
        """Returns (False, results) when terraform output is empty JSON {}."""
        peering_dir = "envs/networking/global/tgw-peering"
        _write_data_tf(tmp_path / peering_dir, SAMPLE_DATA_TF)
        (tmp_path / "envs" / "networking" / "euw2" / "tgw").mkdir(parents=True)

        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "{}"

        config = make_config(tmp_path)
        gate = PeeringGate(config, [peering_dir])

        with patch("lib.peering_gate.subprocess.run", return_value=mock_result):
            all_ready, results = gate.check()

        assert all_ready is False
        assert len(results) == 1
        assert results[0].is_ready is False

    def test_check_returns_not_ready_when_terraform_fails(self, tmp_path: Path) -> None:
        """Returns (False, results) when terraform output command returns non-zero."""
        peering_dir = "envs/networking/global/tgw-peering"
        _write_data_tf(tmp_path / peering_dir, SAMPLE_DATA_TF)
        (tmp_path / "envs" / "networking" / "euw2" / "tgw").mkdir(parents=True)

        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stdout = ""

        config = make_config(tmp_path)
        gate = PeeringGate(config, [peering_dir])

        with patch("lib.peering_gate.subprocess.run", return_value=mock_result):
            all_ready, results = gate.check()

        assert all_ready is False
        assert results[0].is_ready is False
        assert "No state output found" in results[0].reason

    def test_check_returns_true_when_no_tgw_dirs_found(self, tmp_path: Path) -> None:
        """Returns (True, []) when no TGW remote state references found."""
        peering_dir = "envs/networking/global/tgw-peering"
        # Write data.tf with NO tgw keys
        _write_data_tf(tmp_path / peering_dir, '# no remote state references\n')

        config = make_config(tmp_path)
        gate = PeeringGate(config, [peering_dir])

        all_ready, results = gate.check()

        assert all_ready is True
        assert results == []

    def test_force_peering_skips_check(self, tmp_path: Path) -> None:
        """When force_peering=True, returns (True, []) without running terraform."""
        peering_dir = "envs/networking/global/tgw-peering"
        _write_data_tf(tmp_path / peering_dir, SAMPLE_DATA_TF)

        config = make_config(tmp_path, force_peering=True)
        gate = PeeringGate(config, [peering_dir])

        with patch("lib.peering_gate.subprocess.run") as mock_run:
            with patch("lib.peering_gate.log_warn") as mock_warn:
                all_ready, results = gate.check()

        # terraform must NOT have been called
        mock_run.assert_not_called()
        assert all_ready is True
        assert results == []
        mock_warn.assert_called_once()

    def test_check_partial_failure(self, tmp_path: Path) -> None:
        """Returns (False, results) when at least one TGW is not ready."""
        peering_dir = "envs/networking/global/tgw-peering"
        _write_data_tf(tmp_path / peering_dir, SAMPLE_DATA_TF_MULTI)
        (tmp_path / "envs" / "networking" / "euw2" / "tgw").mkdir(parents=True)
        (tmp_path / "envs" / "networking" / "euw1" / "tgw").mkdir(parents=True)

        call_count = 0

        def fake_subprocess(cmd, **kwargs):
            nonlocal call_count
            call_count += 1
            result = MagicMock()
            if call_count == 1:
                # euw2 is ready
                result.returncode = 0
                result.stdout = json.dumps({
                    "transit_gateway": {"value": {"id": "tgw-0abc"}, "type": "object"}
                })
            else:
                # euw1 is not ready
                result.returncode = 0
                result.stdout = "{}"
            return result

        config = make_config(tmp_path)
        gate = PeeringGate(config, [peering_dir])

        with patch("lib.peering_gate.subprocess.run", side_effect=fake_subprocess):
            all_ready, results = gate.check()

        assert all_ready is False
        assert len(results) == 2
        ready_flags = {r.region_short: r.is_ready for r in results}
        assert any(v for v in ready_flags.values())   # at least one ready
        assert any(not v for v in ready_flags.values())  # at least one not ready


# ---------------------------------------------------------------------------
# render_status
# ---------------------------------------------------------------------------


class TestRenderStatus:
    def test_render_status_prints_table(self, tmp_path: Path) -> None:
        """render_status produces output without raising."""
        from rich.console import Console
        from io import StringIO

        config = make_config(tmp_path)
        gate = PeeringGate(config, [])

        results = [
            RegionReadiness(region_short="euw2", tgw_dir="envs/networking/euw2/tgw", is_ready=True, reason="TGW ID: tgw-0abc"),
            RegionReadiness(region_short="euw1", tgw_dir="envs/networking/euw1/tgw", is_ready=False, reason="No state output found"),
        ]

        buf = StringIO()
        test_console = Console(file=buf, highlight=False)
        gate.render_status(results, test_console)

        output = buf.getvalue()
        assert "euw2" in output
        assert "euw1" in output
