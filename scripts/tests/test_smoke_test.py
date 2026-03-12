"""Tests for smoke_test — load_instances, build_test_pairs, run_ping_test,
render_results, and main."""

import json
import subprocess
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
import smoke_test  # type: ignore[import]

# ---------------------------------------------------------------------------
# Helpers / fixtures
# ---------------------------------------------------------------------------

# Cell descriptors matching the schema returned by load_instances().
# Fields: cell_path, env, region, cell, bastion_ip, private_ip, key_name
_INSTANCE_A = {
    "cell_path": "envs/dev/euw2/cell1000",
    "env": "dev",
    "region": "euw2",
    "cell": "cell1000",
    "bastion_ip": "1.2.3.4",
    "private_ip": "10.0.0.1",
    "key_name": "euw2-dev",
}
_INSTANCE_B = {
    "cell_path": "envs/dev/usw2/cell1000",
    "env": "dev",
    "region": "usw2",
    "cell": "cell1000",
    "bastion_ip": "5.6.7.8",
    "private_ip": "10.1.0.1",
    "key_name": "usw2-dev",
}
_INSTANCE_C = {
    "cell_path": "envs/dev/euw1/cell1000",
    "env": "dev",
    "region": "euw1",
    "cell": "cell1000",
    "bastion_ip": "9.10.11.12",
    "private_ip": "10.2.0.1",
    "key_name": "euw1-dev",
}


def _make_raw_instances(cells: list[dict]) -> dict:
    """Build the nested dict format that instances.json uses on disk."""
    raw: dict = {}
    for c in cells:
        raw[c["cell_path"]] = {
            "bastions": {f"bastion-{c['region']}-0": c["bastion_ip"]},
            "private_hosts": {f"host-{c['region']}-0": c["private_ip"]},
        }
    return raw


def _write_instances(tmp_path: Path, cells: list[dict]) -> str:
    p = tmp_path / "instances.json"
    p.write_text(json.dumps(_make_raw_instances(cells)))
    return str(p)


def _make_subprocess_result(returncode: int, stdout: str = "", stderr: str = ""):
    result = MagicMock()
    result.returncode = returncode
    result.stdout = stdout
    result.stderr = stderr
    return result


# ---------------------------------------------------------------------------
# load_instances
# ---------------------------------------------------------------------------


class TestLoadInstances:
    def test_loads_valid_json_file(self, tmp_path: Path) -> None:
        """Loads a valid instances.json and returns a list of cell dicts."""
        path = _write_instances(tmp_path, [_INSTANCE_A, _INSTANCE_B])

        result = smoke_test.load_instances(path)

        assert isinstance(result, list)
        assert len(result) == 2
        regions = {r["region"] for r in result}
        assert regions == {"euw2", "usw2"}

    def test_raises_file_not_found_for_missing_file(self, tmp_path: Path) -> None:
        """Raises FileNotFoundError when the path does not exist."""
        missing = str(tmp_path / "nonexistent.json")
        with pytest.raises(FileNotFoundError):
            smoke_test.load_instances(missing)

    def test_raises_value_error_for_malformed_json(self, tmp_path: Path) -> None:
        """Raises ValueError when the file contains invalid JSON."""
        bad_json = tmp_path / "instances.json"
        bad_json.write_text("{ not valid json }")
        with pytest.raises(ValueError):
            smoke_test.load_instances(str(bad_json))

    def test_raises_value_error_when_root_is_not_dict(self, tmp_path: Path) -> None:
        """Raises ValueError when the JSON root is a list, not an object."""
        bad = tmp_path / "instances.json"
        bad.write_text(json.dumps([{"region": "euw2"}]))
        with pytest.raises(ValueError):
            smoke_test.load_instances(str(bad))


# ---------------------------------------------------------------------------
# build_test_pairs
# ---------------------------------------------------------------------------


class TestBuildTestPairs:
    def test_two_different_regions_returns_two_pairs(self) -> None:
        """Two instances in different regions → 2 ordered pairs (both directions)."""
        pairs = smoke_test.build_test_pairs([_INSTANCE_A, _INSTANCE_B], regions=None)
        assert len(pairs) == 2
        srcs = {p[0]["region"] for p in pairs}
        dsts = {p[1]["region"] for p in pairs}
        assert srcs == {"euw2", "usw2"}
        assert dsts == {"euw2", "usw2"}

    def test_two_same_region_returns_zero_pairs(self) -> None:
        """Two instances in the same region → 0 pairs."""
        same_a = dict(_INSTANCE_A)
        same_b = dict(_INSTANCE_A, bastion_ip="9.9.9.9", private_ip="10.0.0.2")
        pairs = smoke_test.build_test_pairs([same_a, same_b], regions=None)
        assert pairs == []

    def test_four_instances_two_regions_returns_correct_cross_region_pairs(
        self,
    ) -> None:
        """4 instances across 2 regions → only cross-region pairs (no same-region)."""
        inst_a2 = dict(_INSTANCE_A, cell="cell1001", bastion_ip="1.2.3.5", private_ip="10.0.0.2")
        inst_b2 = dict(_INSTANCE_B, cell="cell1001", bastion_ip="5.6.7.9", private_ip="10.1.0.2")
        instances = [_INSTANCE_A, inst_a2, _INSTANCE_B, inst_b2]

        pairs = smoke_test.build_test_pairs(instances, regions=None)

        for src, dst in pairs:
            assert src["region"] != dst["region"], (
                f"Expected cross-region but got {src['region']} → {dst['region']}"
            )
        # 2 euw2 × 2 usw2 in each direction = 8
        assert len(pairs) == 8

    def test_regions_filter_excludes_unmatched_regions(self) -> None:
        """regions filter keeps only pairs where both ends are in the allowed list."""
        instances = [_INSTANCE_A, _INSTANCE_B, _INSTANCE_C]
        pairs = smoke_test.build_test_pairs(instances, regions=["euw2", "usw2"])
        for src, dst in pairs:
            assert src["region"] in ("euw2", "usw2")
            assert dst["region"] in ("euw2", "usw2")
        assert not any(
            p[0]["region"] == "euw1" or p[1]["region"] == "euw1" for p in pairs
        )

    def test_empty_instances_returns_empty(self) -> None:
        """Empty instance list → empty pairs list."""
        pairs = smoke_test.build_test_pairs([], regions=None)
        assert pairs == []


# ---------------------------------------------------------------------------
# run_ping_test
# ---------------------------------------------------------------------------


class TestRunPingTest:
    def test_returncode_zero_gives_pass(self, tmp_path: Path) -> None:
        """subprocess.run returning returncode=0 → status 'PASS'."""
        mock_result = _make_subprocess_result(returncode=0, stdout="3 packets transmitted")

        with patch("smoke_test.subprocess.run", return_value=mock_result):
            result = smoke_test.run_ping_test(
                _INSTANCE_A, _INSTANCE_B, key_dir=str(tmp_path), timeout=30
            )

        assert result["status"] == "PASS"
        assert result["src"] == f"{_INSTANCE_A['region']}/{_INSTANCE_A['cell']}"
        assert result["dst"] == f"{_INSTANCE_B['region']}/{_INSTANCE_B['cell']}"

    def test_returncode_nonzero_gives_fail(self, tmp_path: Path) -> None:
        """subprocess.run returning returncode=1 → status 'FAIL'."""
        mock_result = _make_subprocess_result(returncode=1, stdout="", stderr="unreachable")

        with patch("smoke_test.subprocess.run", return_value=mock_result):
            result = smoke_test.run_ping_test(
                _INSTANCE_A, _INSTANCE_B, key_dir=str(tmp_path), timeout=30
            )

        assert result["status"] == "FAIL"

    def test_timeout_expired_gives_fail_with_timeout_in_output(
        self, tmp_path: Path
    ) -> None:
        """subprocess.TimeoutExpired → status 'FAIL'/'ERROR' and 'timeout' in output."""
        with patch(
            "smoke_test.subprocess.run",
            side_effect=subprocess.TimeoutExpired(cmd="ssh", timeout=30),
        ):
            result = smoke_test.run_ping_test(
                _INSTANCE_A, _INSTANCE_B, key_dir=str(tmp_path), timeout=30
            )

        assert result["status"] in ("FAIL", "ERROR")
        assert "timed out" in result["output"].lower() or "timeout" in result["output"].lower()

    def test_ssh_command_uses_key_path_bastion_and_ping(self, tmp_path: Path) -> None:
        """SSH command includes the key file path, bastion IP, and ping invocation."""
        mock_result = _make_subprocess_result(returncode=0)

        with patch("smoke_test.subprocess.run", return_value=mock_result) as mock_run:
            smoke_test.run_ping_test(
                _INSTANCE_A, _INSTANCE_B, key_dir=str(tmp_path), timeout=30
            )

        assert mock_run.called
        cmd = mock_run.call_args[0][0]
        cmd_str = " ".join(cmd) if isinstance(cmd, list) else cmd
        assert _INSTANCE_A["bastion_ip"] in cmd_str
        assert _INSTANCE_B["private_ip"] in cmd_str
        assert "ping" in cmd_str
        assert _INSTANCE_A["key_name"] in cmd_str


# ---------------------------------------------------------------------------
# render_results
# ---------------------------------------------------------------------------


class TestRenderResults:
    def test_all_pass_contains_pass_indicator(self) -> None:
        """All-PASS results → output contains 'PASS' or 'All paths OK'."""
        results = [
            {"src": "euw2/cell1000", "dst": "usw2/cell1000", "status": "PASS", "latency": "", "output": "ok"},
            {"src": "usw2/cell1000", "dst": "euw2/cell1000", "status": "PASS", "latency": "", "output": "ok"},
        ]
        output = smoke_test.render_results(results)
        assert isinstance(output, str)
        assert len(output) > 0
        assert "PASS" in output or "All paths OK" in output

    def test_mixed_results_shows_both_pass_and_fail(self) -> None:
        """Mixed PASS/FAIL results → both statuses appear in the output."""
        results = [
            {"src": "euw2/cell1000", "dst": "usw2/cell1000", "status": "PASS", "latency": "", "output": "ok"},
            {"src": "euw2/cell1000", "dst": "euw1/cell1000", "status": "FAIL", "latency": "", "output": "err"},
        ]
        output = smoke_test.render_results(results)
        assert "PASS" in output
        assert "FAIL" in output

    def test_empty_results_returns_non_empty_string(self) -> None:
        """Empty results list → returns a non-empty string without crashing."""
        output = smoke_test.render_results([])
        assert isinstance(output, str)
        assert len(output) > 0


# ---------------------------------------------------------------------------
# main (end-to-end with tmp_path + mocked subprocess)
# ---------------------------------------------------------------------------


class TestMain:
    def test_all_pass_exits_zero(self, tmp_path: Path) -> None:
        """All ping tests pass → main returns 0."""
        instances_path = _write_instances(tmp_path, [_INSTANCE_A, _INSTANCE_B])
        mock_result = _make_subprocess_result(returncode=0, stdout="3 packets ok")

        with patch("smoke_test.subprocess.run", return_value=mock_result):
            exit_code = smoke_test.main(
                ["--instances", instances_path, "--key-dir", str(tmp_path)]
            )

        assert exit_code == 0

    def test_one_fail_exits_one(self, tmp_path: Path) -> None:
        """At least one ping test fails → main returns 1."""
        instances_path = _write_instances(tmp_path, [_INSTANCE_A, _INSTANCE_B])

        call_count = 0

        def flaky_subprocess(*_, **__):
            nonlocal call_count
            call_count += 1
            return _make_subprocess_result(returncode=0 if call_count == 1 else 1)

        with patch("smoke_test.subprocess.run", side_effect=flaky_subprocess):
            exit_code = smoke_test.main(
                ["--instances", instances_path, "--key-dir", str(tmp_path)]
            )

        assert exit_code == 1

    def test_dry_run_makes_no_subprocess_calls_and_exits_zero(
        self, tmp_path: Path
    ) -> None:
        """--dry-run flag → subprocess.run is never called, exit code is 0."""
        instances_path = _write_instances(tmp_path, [_INSTANCE_A, _INSTANCE_B])

        with patch("smoke_test.subprocess.run") as mock_run:
            exit_code = smoke_test.main(
                [
                    "--instances", instances_path,
                    "--key-dir", str(tmp_path),
                    "--dry-run",
                ]
            )

        mock_run.assert_not_called()
        assert exit_code == 0
