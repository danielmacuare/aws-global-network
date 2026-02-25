from pathlib import Path

from pydantic import BaseModel, ConfigDict, Field


class TimingRecord(BaseModel):
    """A single directory-level timing record captured during a deployment phase."""

    rel_dir: str
    t_start: float
    t_end: float


class PhaseResult(BaseModel):
    """Aggregated result for one deployment phase (e.g. 'cells', 'tgw')."""

    phase_name: str
    t_start: float
    t_end: float
    records: list[TimingRecord] = Field(default_factory=list)
    failed_dirs: list[str] = Field(default_factory=list)


class RunConfig(BaseModel):
    """Top-level configuration for a deploy or destroy run."""

    model_config = ConfigDict(arbitrary_types_allowed=True)

    environments: list[str] = Field(default_factory=list)
    regions: list[str] = Field(default_factory=list)
    dry_run: bool = False
    skip_peering: bool = False
    force_peering: bool = False
    repo_root: Path
    log_dir: Path
    tgw_stabilise_wait: int = 30
    log_retention: int = 10
