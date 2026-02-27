# Feature-07 | Move deploy/destroy Scripts from Bash to Python

## Description

Replace `scripts/deploy.sh` and `scripts/destroy.sh` with a Python-based CLI toolchain.
The Python implementation must preserve all existing behaviour (parallel execution, phase ordering,
log rotation, timing summary, instance inventory) while adding:

- Structured, readable output via the `rich` library (progress bars, status spinners, tables)
- Proper subprocess management using `subprocess` and `concurrent.futures.ThreadPoolExecutor`
- A **TGW Peering Readiness Gate** — before Phase 3 runs, the script checks that all required
  regions have their TGW state files present and their TGW IDs resolvable via `terraform output`.
  If any region is not ready, the peering phase is skipped with a clear warning rather than
  producing a half-applied peering attachment.
- Typed configuration via **Pydantic BaseModel** for environment and region metadata
- Dry-run mode, region filtering, and environment filtering identical to the bash scripts
- A single entry point `scripts/deploy.py` and `scripts/destroy.py` that mirror the bash
  interface exactly so existing CI/CD invocations continue to work without changes

This feature is planned for implementation by **4 parallel agents** (see Agent Breakdown below).

---

## Dependencies

- Feature 06 complete (all euw1 + global peering infra deployed — required context for
  understanding all discovery paths the new script must handle)
- Python 3.11+ available in the execution environment
- `uv` must be installed: `pip install uv` OR `brew install uv`
- All Python dependencies are managed via `scripts/pyproject.toml` and installed with `uv sync`
- Dependencies: `typer[all]>=0.12`, `pydantic>=2.0`, `rich>=13.0`

---

## Context: Current Bash Scripts

### What the bash scripts do today

| Script | Phases | Mechanism |
|--------|--------|-----------|
| `deploy.sh` | 0: keypairs, 1: TGW+VPC (parallel), wait 30 s, 2: TGW-VPC atts (parallel), 3: TGW Peering (sequential) | bash background jobs + `wait`, associative arrays for timing |
| `destroy.sh` | 1: TGW Peering (sequential), 2: TGW-VPC atts (parallel), wait 30 s, 3: TGW+VPC (parallel), 4: keypairs (parallel) | same |

### Discovery functions (must be replicated in Python)

```
discover_keypairs()      → envs/{dev,prod}/<region>/keypair/
discover_vpc_cells()     → envs/{dev,prod}/<region>/<cell>/      (excludes "keypair")
discover_tgws()          → envs/networking/<region>/tgw/          (excludes "global")
discover_tgw_vpc_atts()  → envs/networking/<region>/tgw-vpc-atts/ (excludes "global")
discover_tgw_peering()   → envs/networking/global/tgw-peering/
```

### Known pain points in the bash implementation

1. Associative arrays require bash 4+; macOS ships bash 3 by default — users need brew-installed bash.
2. Background job tracking via PIDs is fragile; a job failure can be missed if `wait` is not invoked correctly.
3. Timing data is shared via temp files because subshells cannot write to parent associative arrays — adds complexity.
4. No structured logging — all output is plain terminal ANSI codes that don't survive log file redirection well.
5. `collect_timing` uses `tr '_' '/'` to reconstruct directory paths from temp file names — breaks if a directory contains `_` in its path (e.g. `tgw-vpc-atts` becomes `tgw/vpc/atts`).
6. No readiness check before TGW Peering — if a region's TGW is not yet available, `terraform apply` on the peering module will fail mid-apply.

---

## TGW Peering Readiness Gate (Key New Feature)

Before Phase 3 (TGW Peering) executes, the Python script must verify that all regions whose
TGW state is referenced by the peering module are ready.

### Readiness check algorithm

```python
def tgw_ready(region_short: str, state_bucket: str, state_key: str) -> bool:
    """
    Returns True if the TGW for a given region has been successfully applied
    and its transit_gateway output is non-empty.
    Steps:
      1. Run: terraform -chdir=envs/networking/<region>/tgw output -json
      2. Parse JSON; check that output["transit_gateway"]["value"]["id"] exists and is non-empty.
      3. Return True if check passes, False otherwise.
    Alternatively (lighter): check that the S3 state file exists and is non-empty
    via boto3 s3 head_object (no terraform invocation needed).
    """
```

### Behaviour

- If all participating regions are ready → proceed to Phase 3 normally.
- If any region is NOT ready → skip Phase 3, print a `[WARN]` table showing which regions are
  missing, and exit with code 0 (non-fatal) so CI/CD pipelines can retry later.
- The `--skip-peering` flag still overrides this gate entirely.
- A `--force-peering` flag bypasses the readiness check and attempts Phase 3 regardless.

### Regions participating in peering (discovered dynamically)

The peering readiness gate discovers which regions are referenced by reading the `data.tf` file
in `envs/networking/global/tgw-peering/` and extracting `terraform_remote_state` config blocks.
This makes it future-proof — adding a new region to the peering module automatically includes it
in the readiness gate without changing the Python script.

---

## Python Project Structure

```
scripts/
  deploy.py               ← entry point (Typer app)
  destroy.py              ← entry point (Typer app)
  pyproject.toml          ← UV project config with deps
  .python-version         ← pin Python version (3.11)
  lib/
    __init__.py
    config.py             ← Pydantic BaseModel: RunConfig, TimingRecord, PhaseResult
    discovery.py          ← all discover_* functions using pathlib.Path
    runner.py             ← TerraformRunner: init, apply, destroy, plan
    phases.py             ← Phase orchestration: run_parallel_phase(), run_sequential_phase()
    peering_gate.py       ← TGW Peering Readiness Gate
    console.py            ← rich Console setup, log_info / log_phase / log_table helpers
    timing.py             ← TimingSummary collector and renderer
  tests/
    __init__.py
    test_discovery.py
    test_runner.py
    test_peering_gate.py
    test_phases.py
```

Note: `lib/console.py` is named `console` (not `logging`) to avoid shadowing Python's built-in
`logging` module.

---

## CLI Interface (backwards-compatible with bash scripts)

```python
# deploy.py using Typer
import typer
from typing import Optional
from typing_extensions import Annotated

app = typer.Typer()

@app.command()
def main(
    environment: Annotated[str, typer.Option("--environment", "-e", help="dev | prod | all")] = "all",
    regions: Annotated[Optional[str], typer.Option("--regions", "-r", help="euw2,euw1,... (default: all)")] = None,
    dry_run: Annotated[bool, typer.Option("--dry-run", help="terraform plan only")] = False,
    skip_peering: Annotated[bool, typer.Option("--skip-peering", help="skip TGW Peering phase")] = False,
    force_peering: Annotated[bool, typer.Option("--force-peering", help="bypass TGW readiness gate")] = False,
    tgw_wait: Annotated[int, typer.Option("--tgw-wait", help="seconds to wait for TGW stabilisation")] = 30,
):
    ...

if __name__ == "__main__":
    app()
```

Same pattern for `destroy.py`.

Both scripts are also executable (`#!/usr/bin/env python3`) and callable directly:
```bash
./scripts/deploy.py
./scripts/destroy.py
```

---

## Agent Breakdown (4 Implementation Agents)

This feature is divided into 4 agents. Agents A and B can run in parallel.
Agents C and D depend on A and B completing first.

```
┌─────────────────────────┐  ┌─────────────────────────┐
│  Agent A                │  │  Agent B                │
│  lib/config.py          │  │  lib/discovery.py        │
│  lib/console.py         │  │  lib/runner.py           │
│  lib/timing.py          │  │                          │
│  scripts/pyproject.toml │  │                          │
│  scripts/.python-version│  │                          │
└──────────┬──────────────┘  └──────────┬───────────────┘
           │  [both complete]            │
           └──────────┬─────────────────┘
                      ▼
       ┌──────────────┴──────────────────┐
       │  Agent C                        │  Agent D (parallel with C)
       │  lib/phases.py                  │  lib/peering_gate.py
       │  scripts/deploy.py              │  Integration tests
       │  scripts/destroy.py             │  (smoke test against dry-run)
       └─────────────────────────────────┘
```

### Agent A — Core Infrastructure (`lib/config.py`, `lib/console.py`, `lib/timing.py`, `scripts/pyproject.toml`)

**Responsibilities:**

1. `lib/config.py` — **Pydantic BaseModel** (not dataclasses):
   ```python
   from pydantic import BaseModel, Field
   from pathlib import Path

   class RunConfig(BaseModel):
       environments: list[str] = Field(default=["dev", "prod"])
       regions: list[str] = Field(default_factory=list)
       dry_run: bool = False
       skip_peering: bool = False
       force_peering: bool = False
       repo_root: Path
       log_dir: Path
       tgw_stabilise_wait: int = 30
       log_retention: int = 10

   class TimingRecord(BaseModel):
       rel_dir: str
       t_start: float
       t_end: float

   class PhaseResult(BaseModel):
       phase_name: str
       t_start: float
       t_end: float
       records: list[TimingRecord] = Field(default_factory=list)
       failed_dirs: list[str] = Field(default_factory=list)
   ```

2. `lib/console.py` (named `console`, not `logging`, to avoid shadowing stdlib) — `rich`-based console:
   - `log_info()`, `log_success()`, `log_error()`, `log_warn()`, `log_phase()` functions
   - `from rich.console import Console` — a singleton `console` instance shared across the app
   - All output goes to the shared `Console` instance so it renders correctly in both TTY and non-TTY (CI) contexts
   - Log file writing: each terraform invocation writes to `logs/<timestamp>/<dir>.log`

3. `lib/timing.py` — `TimingSummary`:
   - Collects `PhaseResult` objects
   - `render_summary(console)` prints the phase duration table + per-phase directory breakdown using `rich.table.Table`

4. `scripts/pyproject.toml`:
   ```toml
   [project]
   name = "aws-global-network-scripts"
   version = "0.1.0"
   requires-python = ">=3.11"
   dependencies = [
       "rich>=13.0",
       "typer[all]>=0.12",
       "pydantic>=2.0",
   ]

   [tool.uv]
   dev-dependencies = [
       "pytest>=8.0",
   ]
   ```

5. `scripts/.python-version`:
   ```
   3.11
   ```

**Does NOT implement:** discovery, terraform invocation, phase orchestration, peering gate.

---

### Agent B — Discovery and Terraform Runner (`lib/discovery.py`, `lib/runner.py`)

**Responsibilities:**

1. `lib/discovery.py` — mirrors all bash `discover_*` functions:
   ```python
   def discover_keypairs(config: RunConfig) -> list[str]: ...
   def discover_vpc_cells(config: RunConfig) -> list[str]: ...
   def discover_tgws(config: RunConfig) -> list[str]: ...
   def discover_tgw_vpc_atts(config: RunConfig) -> list[str]: ...
   def discover_tgw_peering(config: RunConfig) -> list[str]: ...
   ```
   - **All filesystem path operations MUST use `pathlib.Path` exclusively.** No `os.path` usage.
     No string concatenation for paths. Use `/` operator for path joining
     (e.g. `config.repo_root / "envs" / env / region / cell`).
   - Respects `config.environments` and `config.regions` filters
   - Returns relative path strings (e.g. `"envs/dev/euw1/cell3000"`) to match bash behaviour

2. `lib/runner.py` — `TerraformRunner`:
   ```python
   class TerraformRunner:
       def __init__(self, rel_dir: str, config: RunConfig): ...
       def run(self) -> TimingRecord:
           """Runs terraform init + apply (or plan in dry_run mode).
           Writes stdout+stderr to log file.
           Returns TimingRecord with t_start, t_end, rc."""
   ```
   - Uses `subprocess.run()` with `cwd=abs_dir`
   - Captures output to log file; streams a single status line to console via `log_info` / `log_success` / `log_error`
   - Imports log helpers from `lib/console.py` (not `lib/logging.py`)
   - Raises `TerraformError` on non-zero return code (caller decides whether to abort or continue)

**Does NOT implement:** phase orchestration, peering gate, rich output formatting beyond basic log calls.

---

### Agent C — Phase Orchestration and Entry Points (`lib/phases.py`, `scripts/deploy.py`, `scripts/destroy.py`)

**Depends on:** Agent A (config, console, timing) and Agent B (discovery, runner) being complete.

**Responsibilities:**

1. `lib/phases.py`:
   ```python
   def run_parallel_phase(
       phase_name: str,
       dirs: list[str],
       config: RunConfig,
       console: Console,
   ) -> PhaseResult:
       """Runs all dirs concurrently using ThreadPoolExecutor.
       Returns PhaseResult with timing and any failures."""

   def run_sequential_phase(
       phase_name: str,
       dirs: list[str],
       config: RunConfig,
       console: Console,
   ) -> PhaseResult:
       """Runs dirs one at a time in order.
       Returns PhaseResult."""
   ```
   - Uses `concurrent.futures.ThreadPoolExecutor` for parallel execution
   - On any failure in a parallel phase: collects all failures before raising, not fail-fast
   - Prints a rich `[bold cyan]` phase banner via `log_phase()`

2. `scripts/deploy.py` — complete Typer entry point:
   - Typer app with `@app.command()` decorator; Pydantic `RunConfig` is constructed from Typer callback parameters
   - Imports `Console` from `lib/console.py` (not `lib/logging.py`)
   - Builds `RunConfig`
   - Calls discovery functions → populates KEYPAIRS, VPC_CELLS, TGWS, TGW_ATTS, TGW_PEERING
   - Executes phases in order:
     ```
     Phase 0: run_parallel_phase("Phase 0 — SSH Key Pairs", KEYPAIRS, ...)
     Phase 1: run_parallel_phase("Phase 1 — VPCs + TGWs", TGWS + VPC_CELLS, ...)
     wait(tgw_stabilise_wait)
     Phase 2: run_parallel_phase("Phase 2 — TGW-VPC Attachments", TGW_ATTS, ...)
     Phase 3: peering_gate.check() → run_sequential_phase("Phase 3 — TGW Peering", TGW_PEERING, ...)
     ```
   - Prints instance inventory (runs `terraform output -json instances` per cell)
   - Prints timing summary

3. `scripts/destroy.py` — complete Typer entry point (reverse order):
   - Typer app with `@app.command()` decorator; imports from `lib/console.py`
   ```
   Phase 1: run_sequential_phase("Phase 1 — TGW Peering", TGW_PEERING, ...)
   Phase 2: run_parallel_phase("Phase 2 — TGW-VPC Attachments", TGW_ATTS, ...)
   wait(tgw_stabilise_wait)
   Phase 3: run_parallel_phase("Phase 3 — TGWs + VPCs", TGWS + VPC_CELLS, ...)
   Phase 4: run_parallel_phase("Phase 4 — SSH Key Pairs", KEYPAIRS, ...)
   ```

**Does NOT implement:** peering gate logic, rich logging setup, timing dataclasses.

---

### Agent D — TGW Peering Readiness Gate and Integration Smoke Tests (`lib/peering_gate.py`, `tests/`)

**Depends on:** Agent A (config, console) and Agent B (runner) being complete.

**Responsibilities:**

1. `lib/peering_gate.py`:
   ```python
   from pydantic import BaseModel

   class RegionReadiness(BaseModel):
       region_short: str
       tgw_dir: str
       is_ready: bool
       reason: str        # e.g. "TGW ID: tgw-0abc1234" or "No state output found"

   class PeeringGate:
       def __init__(self, config: RunConfig, peering_dirs: list[str]): ...

       def check(self) -> tuple[bool, list[RegionReadiness]]:
           """
           1. For each dir in peering_dirs, parse data.tf to extract referenced
              TGW state keys (terraform_remote_state blocks with key = "env-networking/*-tgw/*").
           2. For each referenced TGW dir (envs/networking/<region>/tgw/), run:
                  terraform -chdir=<tgw_dir> output -json
              and check that transit_gateway.id is non-empty.
           3. Return (all_ready: bool, results: list[RegionReadiness]) where RegionReadiness
              is a Pydantic BaseModel.
           """

       def render_status(self, results: list[RegionReadiness], console: Console) -> None:
           """Prints a rich table: Region | TGW Dir | Ready | Reason"""
   ```

   - If `config.force_peering` is True, `check()` always returns `(True, [])` with a `[WARN]` message.
   - If `config.skip_peering` is True, gate is never invoked (caller skips Phase 3 entirely).
   - Parsing `data.tf` uses regex `r'key\s*=\s*"([^"]*-tgw[^"]*)"'` to extract TGW state keys —
     no full HCL parser required.

2. `tests/` — smoke tests (no real AWS calls, uses `--dry-run` mode):
   ```
   tests/
     test_discovery.py    — asserts discover_* returns expected relative paths
     test_runner.py       — mocks subprocess, asserts correct terraform commands are built
     test_peering_gate.py — tests gate logic with mock terraform output responses
     test_phases.py       — asserts parallel/sequential execution order and failure handling
   ```
   - Uses `pytest` + `unittest.mock`
   - All tests runnable with: `uv run pytest scripts/tests/ -v`

**Does NOT implement:** phase orchestration, entry points, rich console setup.

---

## Cross-Cutting Import Conventions

All modules must follow these import conventions consistently:

| What | Import from |
|------|------------|
| Console & logging helpers | `from lib.console import console, log_info, log_success, log_error, log_warn, log_phase` |
| Config models | `from lib.config import RunConfig, TimingRecord, PhaseResult` |
| Terraform runner | `from lib.runner import TerraformRunner` |
| Discovery functions | `from lib.discovery import discover_keypairs, discover_vpc_cells, ...` |
| Phase orchestration | `from lib.phases import run_parallel_phase, run_sequential_phase` |
| Peering gate | `from lib.peering_gate import PeeringGate, RegionReadiness` |
| Path operations | `from pathlib import Path` — **never** `import os.path` |
| Pydantic models | `from pydantic import BaseModel, Field` |
| CLI | `import typer` and `from typing import Annotated` (not argparse) |
| Timing | `import time; time.monotonic()` (not `time.time()`) |

---

## Important Notes

- **Backwards compatibility**: The bash scripts (`deploy.sh`, `destroy.sh`) are kept in place until
  the Python scripts are fully tested. They are deprecated but not deleted in this feature.
  Deletion happens as a cleanup task at the end of Feature-07.
- **macOS Python**: macOS ships Python 3.9+; the scripts must work with Python 3.11+. If the
  environment has an older Python, a clear error message with the minimum version requirement
  is printed on startup.
- **No global state**: All state is passed through `RunConfig` and return values. No module-level
  mutable globals (this was a bash pain point).
- **TGW stabilise wait**: The 30-second sleep between Phase 1 and Phase 2 is preserved. It is
  configurable via `RunConfig.tgw_stabilise_wait` (default 30, overridable via `--tgw-wait N`).
- **Log files**: Each terraform invocation writes its full stdout+stderr to
  `logs/<timestamp>/<escaped_dir>.log`. The path escaping uses `-` as separator (not `_`) to
  avoid the bash `tr '_' '/'` round-trip bug.
- **Thread safety**: `rich.console.Console` is thread-safe. All log calls from worker threads
  go through the shared console instance defined in `lib/console.py`.
- **Timing precision**: Use `time.monotonic()` for timing (not `time.time()`) to avoid issues
  with system clock adjustments during long runs.
- **Exit codes**: Exit 1 on any phase failure. Exit 0 if peering is skipped due to readiness gate.
- **Package management**: `scripts/pyproject.toml` is the single source of truth for dependencies.
  Install with `uv sync --project scripts/` or `cd scripts && uv sync`. The venv is created at
  `scripts/.venv/` by UV automatically. Do NOT use a `requirements.txt`. Do NOT pollute the repo
  root with Python packaging files (this is an IaC repo, not a Python package).

---

## Verification

### Setup (one-time)
```bash
cd scripts/
uv sync          # creates .venv and installs all deps including pytest
source .venv/bin/activate  # or use `uv run` prefix
```

### Unit tests
```bash
cd scripts && uv sync     # installs all deps including pytest (dev dep)
uv run pytest tests/ -v   # runs from scripts/ directory
```

### Dry-run smoke test (no AWS changes)
```bash
uv run python deploy.py --dry-run
uv run python destroy.py --dry-run

# Or activate venv and run directly
source scripts/.venv/bin/activate
python scripts/deploy.py --dry-run
python scripts/destroy.py --dry-run
```

### Functional equivalence test
Run both bash and Python scripts in `--dry-run` mode; diff their discovered directories:
```bash
# Extract directories from bash dry-run log
bash scripts/deploy.sh --dry-run 2>&1 | grep "Planning:" | sort > /tmp/bash_dirs.txt

# Extract directories from Python dry-run log
python scripts/deploy.py --dry-run 2>&1 | grep "Planning:" | sort > /tmp/python_dirs.txt

diff /tmp/bash_dirs.txt /tmp/python_dirs.txt   # should be empty
```

### Phase ordering validation
With `--dry-run`, confirm that Phase 0 completes before Phase 1 starts, etc., by checking
timestamps in the output.

### TGW Peering Readiness Gate test
```bash
# Simulate missing region: temporarily rename euw1 tgw dir
mv envs/networking/euw1/tgw envs/networking/euw1/tgw.bak
python scripts/deploy.py --dry-run
# Expect: [WARN] TGW Peering skipped — euw1 not ready
mv envs/networking/euw1/tgw.bak envs/networking/euw1/tgw
```

### tflint / terraform validate (not applicable — no .tf files changed)
```bash
# Verify scripts directory has no .tf files inadvertently modified
terraform fmt --recursive $PROJECT_NAME
```

---

## README Specification (`scripts/README.md`)

The README must cover:

### Quick Start
```bash
# Prerequisites: Python 3.11+, uv, terraform, AWS credentials configured
# Install uv: pip install uv  OR  brew install uv

cd /path/to/aws-global-network
uv sync --project scripts/    # installs all Python deps into scripts/.venv
```

### Running deploy
```bash
# Full deploy (all envs, all regions)
uv run --project scripts/ python scripts/deploy.py

# Or with venv activated
source scripts/.venv/bin/activate
python scripts/deploy.py

# Common options
python scripts/deploy.py -e dev                    # dev only
python scripts/deploy.py -r euw2,euw1              # specific regions
python scripts/deploy.py --dry-run                 # preview only
python scripts/deploy.py --skip-peering            # skip TGW peering phase
python scripts/deploy.py --force-peering           # bypass readiness gate
python scripts/deploy.py --tgw-wait 60             # custom stabilisation wait
```

### Running destroy
```bash
python scripts/destroy.py                          # destroy all
python scripts/destroy.py -e dev --dry-run         # preview dev teardown
```

### Running tests
```bash
uv run --project scripts/ pytest scripts/tests/ -v
```

### Logs
All terraform output is written to `logs/<timestamp>/<dir>.log`.
Log rotation keeps the 10 most recent run directories.

---

## Files to Create

| Agent | File | Action |
|-------|------|--------|
| A | `scripts/pyproject.toml` | Create |
| A | `scripts/.python-version` | Create |
| A | `scripts/lib/__init__.py` | Create |
| A | `scripts/lib/config.py` | Create (Pydantic) |
| A | `scripts/lib/console.py` | Create (was logging.py) |
| A | `scripts/lib/timing.py` | Create |
| B | `scripts/lib/discovery.py` | Create (pathlib) |
| B | `scripts/lib/runner.py` | Create |
| C | `scripts/lib/phases.py` | Create |
| C | `scripts/deploy.py` | Create (Typer) |
| C | `scripts/destroy.py` | Create (Typer) |
| D | `scripts/lib/peering_gate.py` | Create |
| D | `scripts/tests/__init__.py` | Create |
| D | `scripts/tests/test_discovery.py` | Create |
| D | `scripts/tests/test_runner.py` | Create |
| D | `scripts/tests/test_peering_gate.py` | Create |
| D | `scripts/tests/test_phases.py` | Create |
| — | `scripts/README.md` | Create (new) |
| — | `specs/index.md` | Edit (mark 07 as Complete when done) |

## Files to Deprecate (kept, not deleted, until Feature-07 is fully verified)

| File | Action |
|------|--------|
| `scripts/deploy.sh` | Mark as `# DEPRECATED: use deploy.py` in header comment |
| `scripts/destroy.sh` | Mark as `# DEPRECATED: use destroy.py` in header comment |
