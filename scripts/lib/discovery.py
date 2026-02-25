"""
discovery.py — Terraform directory discovery functions.

Each function walks the envs/ tree using pathlib.Path exclusively and returns
a sorted list of relative path strings (relative to repo_root).
"""

from pathlib import Path

from lib.config import RunConfig


def _has_tf_files(directory: Path) -> bool:
    """Return True if *directory* contains at least one *.tf file."""
    return any(directory.glob("*.tf"))


def _region_included(region: str, config: RunConfig) -> bool:
    """Return True if *region* passes the regions filter (empty list = all)."""
    if not config.regions:
        return True
    return region in config.regions


def discover_keypairs(config: RunConfig) -> list[str]:
    """
    Discover dedicated key-pair directories.

    Looks for: envs/{dev,prod}/<region>/keypair/
    Returns relative path strings like 'envs/dev/euw2/keypair', sorted.
    """
    results: list[str] = []
    envs_root = config.repo_root / "envs"

    for env in config.environments:
        env_dir = envs_root / env
        if not env_dir.is_dir():
            continue

        for region_dir in env_dir.iterdir():
            if not region_dir.is_dir():
                continue
            region = region_dir.name
            if not _region_included(region, config):
                continue

            keypair_dir = region_dir / "keypair"
            if not keypair_dir.is_dir():
                continue
            if not _has_tf_files(keypair_dir):
                continue

            results.append(str(keypair_dir.relative_to(config.repo_root)))

    return sorted(results)


def discover_vpc_cells(config: RunConfig) -> list[str]:
    """
    Discover VPC cell directories (all subdirs except 'keypair').

    Looks for: envs/{dev,prod}/<region>/<cell>/
    Returns relative path strings like 'envs/dev/euw2/cell1000', sorted.
    """
    results: list[str] = []
    envs_root = config.repo_root / "envs"

    for env in config.environments:
        env_dir = envs_root / env
        if not env_dir.is_dir():
            continue

        for region_dir in env_dir.iterdir():
            if not region_dir.is_dir():
                continue
            region = region_dir.name
            if not _region_included(region, config):
                continue

            for cell_dir in region_dir.iterdir():
                if not cell_dir.is_dir():
                    continue
                if cell_dir.name == "keypair":
                    continue
                if not _has_tf_files(cell_dir):
                    continue

                results.append(str(cell_dir.relative_to(config.repo_root)))

    return sorted(results)


def discover_tgws(config: RunConfig) -> list[str]:
    """
    Discover regional Transit Gateway directories.

    Looks for: envs/networking/<region>/tgw/  (excludes 'global' region)
    Returns relative path strings like 'envs/networking/euw2/tgw', sorted.
    """
    results: list[str] = []
    networking_dir = config.repo_root / "envs" / "networking"

    if not networking_dir.is_dir():
        return results

    for region_dir in networking_dir.iterdir():
        if not region_dir.is_dir():
            continue
        region = region_dir.name
        if region == "global":
            continue
        if not _region_included(region, config):
            continue

        tgw_dir = region_dir / "tgw"
        if not tgw_dir.is_dir():
            continue
        if not _has_tf_files(tgw_dir):
            continue

        results.append(str(tgw_dir.relative_to(config.repo_root)))

    return sorted(results)


def discover_tgw_vpc_atts(config: RunConfig) -> list[str]:
    """
    Discover TGW-VPC Attachment directories.

    Looks for: envs/networking/<region>/tgw-vpc-atts/  (excludes 'global' region)
    Returns relative path strings like 'envs/networking/euw2/tgw-vpc-atts', sorted.
    """
    results: list[str] = []
    networking_dir = config.repo_root / "envs" / "networking"

    if not networking_dir.is_dir():
        return results

    for region_dir in networking_dir.iterdir():
        if not region_dir.is_dir():
            continue
        region = region_dir.name
        if region == "global":
            continue
        if not _region_included(region, config):
            continue

        att_dir = region_dir / "tgw-vpc-atts"
        if not att_dir.is_dir():
            continue
        if not _has_tf_files(att_dir):
            continue

        results.append(str(att_dir.relative_to(config.repo_root)))

    return sorted(results)


def discover_tgw_peering(config: RunConfig) -> list[str]:
    """
    Discover the TGW Peering Attachment directory.

    Looks for: envs/networking/global/tgw-peering/
    Returns ['envs/networking/global/tgw-peering'] if it exists with .tf files,
    otherwise returns [].
    """
    peering_dir = config.repo_root / "envs" / "networking" / "global" / "tgw-peering"

    if not peering_dir.is_dir():
        return []
    if not _has_tf_files(peering_dir):
        return []

    return [str(peering_dir.relative_to(config.repo_root))]
