# AWS Global Network — Deployment Scripts

## Overview

These Python scripts replace the legacy bash deployment scripts with a structured, testable pipeline that orchestrates Terraform across all environments and regions. They run each deployment phase (key pairs, VPC cells, TGWs, TGW attachments, and TGW peering) in the correct order, with parallel execution where safe and sequential execution where required (e.g. TGW peering). A readiness gate prevents TGW peering from running before all required Transit Gateways have been successfully applied.

---

## Prerequisites

- **Python 3.11+**
- **[uv](https://github.com/astral-sh/uv)** — Python package manager
- **Terraform** — must be on `$PATH`
- **AWS credentials** — configured via environment variables, `~/.aws/credentials`, or an IAM role

---

## Quick Start

```bash
# Install uv if not already installed
pip install uv   # or: brew install uv

# From repo root — install all Python deps into scripts/.venv
uv sync --project scripts/
```

---

## Running Deploy

```bash
# Full deploy (all envs, all regions)
uv run --project scripts/ python scripts/deploy.py

# Or activate the venv first
source scripts/.venv/bin/activate
python scripts/deploy.py

# Options
python scripts/deploy.py --help
python scripts/deploy.py -e dev                  # dev only
python scripts/deploy.py -r euw2,euw1            # specific regions
python scripts/deploy.py --dry-run               # preview only (no changes)
python scripts/deploy.py --skip-peering          # skip TGW Peering phase
python scripts/deploy.py --force-peering         # bypass readiness gate
python scripts/deploy.py --tgw-wait 60           # custom TGW stabilisation wait (seconds)
```

---

## Running Validate

```bash
# Validate all Terraform directories (default parallelism = cpu count)
uv run --project scripts/ python scripts/tf_validate.py

# Custom parallelism
uv run --project scripts/ python scripts/tf_validate.py --parallelism 16

# Options
python scripts/tf_validate.py --help
```

Runs `terraform validate` in parallel across all directories under `bootstrap/`, `envs/`, and `modules/`. Outputs a table showing each directory, pass/fail status, and how long validation took. Failures are sorted to the top of the table and printed in full at the bottom.

---

## Running Smoke Tests

`scripts/smoke_test.py` automates the full end-to-end connectivity verification across all 16 cells. It requires `instances.json` in the repo root (written automatically by `deploy.py`, or on demand via `--json-only`).

### How It Works

For each cell in each environment the script runs a three-step test:

```
1. ProxyCommand through bastion  →  ssh -i ssh-keys/<region>-<env>.pem -o ProxyCommand=... ubuntu@<bastion-ip>
2. SSH to private host           →  ubuntu@<private-ip>
3. Ping all same-env peers       →  ping -c 4 -W 5 <target-private-ip>  (run in parallel with &)
```

- **Same-env isolation** — dev cells only ping dev cells; prod cells only ping prod cells.
- **Parallel pings** — all destination pings fire simultaneously from the private host via bash `&`/`wait`, so a cell with 7 targets takes the time of one ping, not seven.
- **Parallel source cells** — all source cells within an environment are tested concurrently via `ThreadPoolExecutor`, so the full suite runs in roughly the time of the slowest single cell test.
- **RTT capture** — ping output is written to `/tmp/smoke_<cell>` temp files; average RTT is extracted and shown in the results table.
- **Rich table output** — results grouped by ENV with Source, Destination, Status (colour-coded), Latency, and Duration columns.

### Quick Start

```bash
# Run all tests (reads instances.json from repo root)
python scripts/smoke_test.py

# Dry-run — print what would be tested without SSHing
python scripts/smoke_test.py --dry-run

# Filter to specific regions
python scripts/smoke_test.py --regions euw1,euw2

# Stop on first failure
python scripts/smoke_test.py --fail-fast

# Debug mode — print full SSH command and ping targets for each cell
python scripts/smoke_test.py --debug
```

### All Options

| Flag | Default | Description |
|---|---|---|
| `--instances PATH` | `instances.json` | Path to the instances inventory file |
| `--key-dir DIR` | `ssh-keys/` | Directory containing `<region>-<env>.pem` key files |
| `--timeout SECONDS` | `180` | Per-cell SSH+ping timeout (covers the entire session) |
| `--regions r1,r2,...` | all | Comma-separated region short-names to filter tests |
| `--dry-run` | off | Print test plan without running SSH |
| `--debug` | off | Print SSH command and per-destination ping targets |
| `--fail-fast` | off | Stop all remaining tests on first FAIL or ERROR |

### Prerequisites

- `instances.json` must exist in the repo root. Deploy creates it automatically; to refresh stale IPs:
  ```bash
  python scripts/deploy.py --json-refresh
  ```
- SSH key files must be present at `ssh-keys/<region>-<env>.pem` with `chmod 400`.
- Your local SSH agent must **not** have other keys loaded that would cause `MaxAuthTries` failures — the script uses `IdentitiesOnly=yes` to use only the specified key.

### Exit Codes

| Code | Meaning |
|---|---|
| `0` | All tests passed (or `--dry-run`) |
| `1` | One or more tests failed or errored |
| `2` | Configuration error (missing `instances.json`, no cells found, etc.) |

---

## Running Destroy

```bash
python scripts/destroy.py                        # destroy all
python scripts/destroy.py -e dev                 # destroy dev only
python scripts/destroy.py --dry-run              # preview teardown
```

---

## Deployment Phases

The deploy script runs the following phases in order:

| Phase | Description | Execution Mode |
|---|---|---|
| **keypairs** | Creates EC2 key pairs per region/environment | Parallel |
| **vpc-cells** | Deploys VPC cells (subnets, route tables, security groups, etc.) | Parallel |
| **tgw** | Deploys regional Transit Gateways | Parallel |
| **tgw-vpc-atts** | Creates TGW-VPC attachments for all cells | Parallel |
| **tgw-peering** | Configures cross-region TGW peering attachments | Sequential |

The destroy script runs these phases in reverse order.

---

## TGW Peering Readiness Gate

Before the `tgw-peering` phase runs, the script checks that all Transit Gateways referenced in the peering `data.tf` files have been successfully applied and have a non-empty `transit_gateway.id` output in their Terraform state.

If any TGW is not yet ready, the deployment halts and prints a status table showing which regions are ready and which are not.

**Bypassing the gate:**

| Flag | Behaviour |
|---|---|
| `--skip-peering` | Skips the TGW peering phase entirely (no peering applied) |
| `--force-peering` | Bypasses the readiness gate and runs peering regardless |

Use `--force-peering` only when you are certain all TGWs are already applied — for example, when re-running a partially failed deployment.

---

## Running Tests

```bash
uv run --project scripts/ pytest scripts/tests/ -v
```

The test suite uses `pytest` with `unittest.mock` — no real AWS calls or Terraform executions are made.

---

## Logs

Each run creates a timestamped directory under `logs/<timestamp>/`. Each Terraform directory gets its own log file named using `-` as a separator (e.g. `envs-dev-euw2-cell1000.log`).

The script automatically rotates logs, retaining only the 10 most recent run directories (configurable via `--log-retention`).

---

## Migrating from Bash Scripts

The bash scripts (`scripts/deploy.sh` and `scripts/destroy.sh`) are **deprecated** and should no longer be used. The Python equivalents (`scripts/deploy.py` and `scripts/destroy.py`) provide equivalent functionality with improved error handling, parallel execution, structured logging, and a TGW readiness gate.

Use the Python scripts for all new deployments.
