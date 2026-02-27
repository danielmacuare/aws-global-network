"""Tests for lib.discovery — all discover_* functions."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
from lib.config import RunConfig
from lib.discovery import (
    discover_keypairs,
    discover_tgw_peering,
    discover_tgws,
    discover_vpc_cells,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def make_config(tmp_path: Path, **kwargs) -> RunConfig:
    defaults = dict(
        environments=["dev", "prod"],
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


def _touch_tf(path: Path) -> None:
    """Create a minimal main.tf at the given path, creating parent dirs as needed."""
    path.mkdir(parents=True, exist_ok=True)
    (path / "main.tf").write_text("# placeholder\n")


# ---------------------------------------------------------------------------
# discover_keypairs
# ---------------------------------------------------------------------------


class TestDiscoverKeypairs:
    def test_discover_keypairs_returns_only_keypair_dirs(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "keypair")
        config = make_config(tmp_path, environments=["dev"])
        result = discover_keypairs(config)
        assert result == ["envs/dev/euw2/keypair"]

    def test_discover_keypairs_ignores_non_keypair_dirs(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "cell1000")
        config = make_config(tmp_path, environments=["dev"])
        result = discover_keypairs(config)
        assert result == []

    def test_discover_keypairs_filters_by_region(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "keypair")
        _touch_tf(tmp_path / "envs" / "dev" / "euw1" / "keypair")
        config = make_config(tmp_path, environments=["dev"], regions=["euw2"])
        result = discover_keypairs(config)
        assert result == ["envs/dev/euw2/keypair"]

    def test_discover_keypairs_returns_empty_when_no_tf_files(
        self, tmp_path: Path
    ) -> None:
        # Create directory but no .tf files
        (tmp_path / "envs" / "dev" / "euw2" / "keypair").mkdir(parents=True)
        config = make_config(tmp_path, environments=["dev"])
        result = discover_keypairs(config)
        assert result == []


# ---------------------------------------------------------------------------
# discover_vpc_cells
# ---------------------------------------------------------------------------


class TestDiscoverVpcCells:
    def test_discover_vpc_cells_excludes_keypair(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "keypair")
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "cell1000")
        config = make_config(tmp_path, environments=["dev"])
        result = discover_vpc_cells(config)
        assert "envs/dev/euw2/cell1000" in result
        assert "envs/dev/euw2/keypair" not in result

    def test_discover_vpc_cells_filters_by_region(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "cell1000")
        _touch_tf(tmp_path / "envs" / "dev" / "euw1" / "cell1000")
        config = make_config(tmp_path, environments=["dev"], regions=["euw2"])
        result = discover_vpc_cells(config)
        assert result == ["envs/dev/euw2/cell1000"]

    def test_discover_vpc_cells_returns_multiple_cells(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "cell1000")
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "cell1001")
        config = make_config(tmp_path, environments=["dev"])
        result = discover_vpc_cells(config)
        assert "envs/dev/euw2/cell1000" in result
        assert "envs/dev/euw2/cell1001" in result

    def test_discover_vpc_cells_across_environments(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "cell1000")
        _touch_tf(tmp_path / "envs" / "prod" / "euw2" / "cell1000")
        config = make_config(tmp_path, environments=["dev", "prod"])
        result = discover_vpc_cells(config)
        assert "envs/dev/euw2/cell1000" in result
        assert "envs/prod/euw2/cell1000" in result


# ---------------------------------------------------------------------------
# discover_tgws
# ---------------------------------------------------------------------------


class TestDiscoverTgws:
    def test_discover_tgws_excludes_global(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "networking" / "global" / "tgw")
        _touch_tf(tmp_path / "envs" / "networking" / "euw2" / "tgw")
        config = make_config(tmp_path)
        result = discover_tgws(config)
        assert "envs/networking/euw2/tgw" in result
        assert "envs/networking/global/tgw" not in result

    def test_discover_tgws_filters_by_region(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "networking" / "euw2" / "tgw")
        _touch_tf(tmp_path / "envs" / "networking" / "euw1" / "tgw")
        config = make_config(tmp_path, regions=["euw2"])
        result = discover_tgws(config)
        assert result == ["envs/networking/euw2/tgw"]

    def test_discover_tgws_returns_empty_when_networking_missing(
        self, tmp_path: Path
    ) -> None:
        config = make_config(tmp_path)
        result = discover_tgws(config)
        assert result == []

    def test_discover_tgws_ignores_non_tgw_dirs(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "networking" / "euw2" / "tgw-vpc-atts")
        config = make_config(tmp_path)
        result = discover_tgws(config)
        assert result == []


# ---------------------------------------------------------------------------
# discover_tgw_peering
# ---------------------------------------------------------------------------


class TestDiscoverTgwPeering:
    def test_discover_tgw_peering_returns_global_dir(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "networking" / "global" / "tgw-peering")
        config = make_config(tmp_path)
        result = discover_tgw_peering(config)
        assert result == ["envs/networking/global/tgw-peering"]

    def test_discover_tgw_peering_returns_empty_when_missing(
        self, tmp_path: Path
    ) -> None:
        config = make_config(tmp_path)
        result = discover_tgw_peering(config)
        assert result == []

    def test_discover_tgw_peering_returns_empty_when_no_tf_files(
        self, tmp_path: Path
    ) -> None:
        (tmp_path / "envs" / "networking" / "global" / "tgw-peering").mkdir(
            parents=True
        )
        config = make_config(tmp_path)
        result = discover_tgw_peering(config)
        assert result == []


# ---------------------------------------------------------------------------
# Sorted results
# ---------------------------------------------------------------------------


class TestSortedResults:
    def test_discover_returns_sorted_results(self, tmp_path: Path) -> None:
        # Create cells out of alphabetical order
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "cell1002")
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "cell1000")
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "cell1001")
        config = make_config(tmp_path, environments=["dev"])
        result = discover_vpc_cells(config)
        assert result == sorted(result)

    def test_discover_keypairs_returns_sorted_results(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "prod" / "euw2" / "keypair")
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "keypair")
        config = make_config(tmp_path, environments=["dev", "prod"])
        result = discover_keypairs(config)
        assert result == sorted(result)

    def test_discover_tgws_returns_sorted_results(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "networking" / "euw2" / "tgw")
        _touch_tf(tmp_path / "envs" / "networking" / "euw1" / "tgw")
        config = make_config(tmp_path)
        result = discover_tgws(config)
        assert result == sorted(result)


# ---------------------------------------------------------------------------
# usw2 and use1 region discovery
# ---------------------------------------------------------------------------


class TestDiscoverUsw2Use1:
    def test_discover_vpc_cells_picks_up_usw2_and_use1(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "dev" / "usw2" / "cell5000")
        _touch_tf(tmp_path / "envs" / "prod" / "usw2" / "cell4000")
        _touch_tf(tmp_path / "envs" / "dev" / "use1" / "cell7000")
        _touch_tf(tmp_path / "envs" / "prod" / "use1" / "cell6000")
        config = make_config(tmp_path, environments=["dev", "prod"])
        result = discover_vpc_cells(config)
        assert "envs/dev/usw2/cell5000" in result
        assert "envs/prod/usw2/cell4000" in result
        assert "envs/dev/use1/cell7000" in result
        assert "envs/prod/use1/cell6000" in result

    def test_discover_tgws_picks_up_usw2_and_use1(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "networking" / "usw2" / "tgw")
        _touch_tf(tmp_path / "envs" / "networking" / "use1" / "tgw")
        config = make_config(tmp_path)
        result = discover_tgws(config)
        assert "envs/networking/usw2/tgw" in result
        assert "envs/networking/use1/tgw" in result

    def test_discover_keypairs_picks_up_usw2_and_use1(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "dev" / "usw2" / "keypair")
        _touch_tf(tmp_path / "envs" / "prod" / "use1" / "keypair")
        config = make_config(tmp_path, environments=["dev", "prod"])
        result = discover_keypairs(config)
        assert "envs/dev/usw2/keypair" in result
        assert "envs/prod/use1/keypair" in result

    def test_region_filter_usw2_only(self, tmp_path: Path) -> None:
        _touch_tf(tmp_path / "envs" / "dev" / "usw2" / "cell5000")
        _touch_tf(tmp_path / "envs" / "dev" / "use1" / "cell7000")
        _touch_tf(tmp_path / "envs" / "dev" / "euw2" / "cell1000")
        config = make_config(tmp_path, environments=["dev"], regions=["usw2"])
        result = discover_vpc_cells(config)
        assert "envs/dev/usw2/cell5000" in result
        assert "envs/dev/use1/cell7000" not in result
        assert "envs/dev/euw2/cell1000" not in result
