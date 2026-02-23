# Spec 01 - Build Script: Parallel Deployment of VPCs, TGW, and TGW-VPC Attachments

## Overview

A bash script (`scripts/deploy.sh`) that automates the full deployment of all environment cells, the regional Transit Gateway, and all TGW-VPC Attachments. The script maximises parallelism where dependencies allow, includes a 30-second stabilisation window after TGW creation before starting TGW-VPC Attachments, and reserves TGW Peering Attachments as the final sequential step.

**Status**: `scripts/deploy.sh` is implemented and complete.

---

## Goals

1. Deploy all VPCs/cells in `envs/dev/<region_name>/<vpc_name>/` and `envs/prod/<region_name>/<vpc_name>/` in parallel.
2. Deploy the regional TGW at `envs/networking/<region_name>/tgw/` in parallel with VPCs (both are independent).
3. Wait 30 seconds after Phase 1 for AWS TGW propagation (only if TGW-VPC attachments exist).
4. Deploy TGW-VPC Attachments at `envs/networking/<region_name>/tgw-vpc-atts/` after the wait.
5. Deploy TGW Peering Attachments (inter-region) last, sequentially, as they depend on all regional TGWs being available.
6. Provide clear, colour-coded logging and fail-fast error handling.

---

## Dependency Analysis

The deployment has these hard dependencies:

```
VPCs (parallel) ──────────────────────────────────────┐
                                                       │
TGW (can start in parallel with VPCs) ────────────────┤
                                                       │
                                    30-second wait ───►│
                                                       │
                             TGW-VPC Attachments ──────┘
                             (depends on: VPCs ready + TGW ready)
                                                       │
                             TGW Peering Attachments ──┘
                             (depends on: all regional TGWs ready)
```

### What can run in parallel

| Phase | Resources | Parallelism |
|-------|-----------|-------------|
| Phase 1 | All VPCs across all regions + all regional TGWs | Full parallel (all independent of each other) |
| Phase 2 | TGW-VPC Attachments per region | Per-region parallel (after VPCs + TGW + 30s wait) |
| Phase 3 | TGW Peering Attachments | Sequential (all regional TGWs must exist) |

**Key insight**: VPCs and TGWs have no dependency on each other. They are both launched simultaneously in Phase 1. TGW-VPC Attachments depend on both, so they form Phase 2. Peering Attachments form Phase 3 as they wire TGWs across regions.

---

## Script Design

### File Location

```
scripts/deploy.sh
```

### Requirements

- bash 4.0 or later (enforced by a version guard at startup).
- `terraform` binary on `$PATH`.
- AWS credentials configured (environment variables or instance profile).
- Run from the repository root (the script enforces this via `REPO_ROOT`).

### Script Arguments

```bash
./scripts/deploy.sh [OPTIONS]

Options:
  -e, --environment   Environments: dev, prod, or all (default: all)
  -r, --regions       Comma-separated list of regions, e.g. euw2,use1 (default: all discovered)
  --dry-run           Run terraform plan instead of apply (preview changes without applying)
  --skip-peering      Skip TGW Peering Attachment phase
  -h, --help          Show usage
```

### Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `TGW_STABILISE_WAIT` | `30` | Seconds to wait after Phase 1 before Phase 2 |
| `LOG_RETENTION` | `10` | Number of log run directories to keep |

### Region Discovery

The script auto-discovers regions by scanning the directory structure using four dedicated functions:

```bash
discover_vpc_cells      # envs/{dev,prod}/<region>/<cell>/
discover_tgws           # envs/networking/<region>/tgw/
discover_tgw_vpc_atts   # envs/networking/<region>/tgw-vpc-atts/
discover_tgw_peering    # envs/networking/global/tgw-peering/
```

The `--regions` filter is applied inside each discovery function. The `global` pseudo-region is explicitly excluded from TGW and attachment discovery (peering is handled separately).

Discovery functions skip directories that contain no `.tf` files.

Example directory layout the script navigates:

```
envs/
  dev/
    euw2/
      cell1000/         # VPC cell (deployed in Phase 1, parallel)
      cell1001/         # VPC cell (deployed in Phase 1, parallel)
  prod/
    euw2/
      cell0000/         # VPC cell (deployed in Phase 1, parallel)
  networking/
    euw2/
      tgw/              # Regional TGW (Phase 1, parallel)
      tgw-vpc-atts/     # TGW-VPC Attachments (Phase 2, after VPCs+TGW+30s)
    global/
      tgw-peering/      # TGW Peering Attachments (Phase 3, sequential)
```

---

## Execution Flow

### Startup

1. Enforce bash 4.0+.
2. Resolve `REPO_ROOT` from the script's own location (`dirname "${BASH_SOURCE[0]}"/../`).
3. Create a timestamped log directory (`logs/<YYYY-MM-DDTHH-MM-SS>/`).
4. Rotate old log directories (keep last `LOG_RETENTION` runs).
5. Print a startup summary (repo root, log dir, environments, regions, dry-run, skip-peering flags).
6. Run all four discovery functions using `mapfile -t`.
7. Abort with a warning if nothing is found.

### Phase 1 - Parallel: VPCs + TGWs

All VPC cells and all regional TGWs are launched as background jobs simultaneously:

```bash
for dir in "${VPC_CELLS[@]}" "${TGWS[@]}"; do
  run_terraform "$dir" &
  JOB_MAP[$!]="$dir"
done

wait_for_jobs "Phase 1"
```

### 30-Second Wait

After Phase 1 completes (only if TGW-VPC attachment directories were discovered):

```bash
log_info "Waiting ${TGW_STABILISE_WAIT}s for TGW to stabilise before creating attachments..."
sleep "$TGW_STABILISE_WAIT"
```

### Phase 2 - Parallel: TGW-VPC Attachments

One job per region, launched in parallel:

```bash
for dir in "${TGW_ATTS[@]}"; do
  run_terraform "$dir" &
  JOB_MAP[$!]="$dir"
done

wait_for_jobs "Phase 2"
```

Skipped entirely (with a warning) if no `tgw-vpc-atts` directories are discovered.

### Phase 3 - Sequential: TGW Peering Attachments

Only if a `tgw-peering` directory exists and `--skip-peering` is not set:

```bash
for dir in "${TGW_PEERING[@]}"; do
  run_terraform "$dir"   # No & — sequential, blocking
done
```

Skipped with a warning if no peering directories are found or `--skip-peering` is passed.

---

## Helper Functions

### `run_terraform`

Wraps `terraform init && terraform apply -auto-approve` (or `terraform plan` in dry-run mode) with:
- Absolute path resolution from `REPO_ROOT`.
- `.tf` file existence check — skips with a warning if none found.
- Per-deployment log file (`logs/<timestamp>/<dir-with-slashes-replaced-by-underscores>.log`).
- `init` output always written to log only; `plan` output piped through `tee` for console visibility.
- Coloured success/failure output on completion.
- Returns non-zero on failure (callers decide whether to abort).

```bash
run_terraform() {
  local rel_dir="$1"
  local abs_dir="${REPO_ROOT}/${rel_dir}"
  local log_name
  log_name="$(echo "$rel_dir" | tr '/' '_').log"
  local log_file="${LOG_DIR}/${log_name}"

  if ! ls "${abs_dir}"/*.tf >/dev/null 2>&1; then
    log_warn "Skipping ${rel_dir} — no .tf files found"
    return 0
  fi

  local rc=0
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Planning: ${rel_dir}"
    (
      cd "$abs_dir"
      terraform init -input=false >> "$log_file" 2>&1
      terraform plan -input=false 2>&1 | tee -a "$log_file"
    ) || rc=$?
  else
    log_info "Deploying: ${rel_dir}"
    (
      cd "$abs_dir"
      terraform init -input=false >> "$log_file" 2>&1
      terraform apply -auto-approve -input=false >> "$log_file" 2>&1
    ) || rc=$?
  fi

  if [[ $rc -eq 0 ]]; then
    log_success "Done: ${rel_dir}"
  else
    log_error "FAILED: ${rel_dir} — see ${log_file}"
  fi
  return $rc
}
```

### `wait_for_jobs`

Uses an associative array `JOB_MAP` (keyed by PID, value is the directory path) to track background jobs. Waits for every tracked PID and accumulates failures. If any job failed, logs all failures and exits the script immediately (fail-fast):

```bash
wait_for_jobs() {
  local phase_label="$1"
  local failed=0
  local pid dir

  for pid in "${!JOB_MAP[@]}"; do
    dir="${JOB_MAP[$pid]}"
    wait "$pid" || {
      failed=$((failed + 1))
      log_error "Job failed — ${dir}"
    }
  done

  JOB_MAP=()   # Reset for next phase

  if [[ $failed -gt 0 ]]; then
    log_error "${phase_label} — ${failed} job(s) failed. Aborting."
    exit 1
  fi
}
```

### `rotate_logs`

Keeps only the most recent `LOG_RETENTION` (10) run directories under `logs/`. Older directories are deleted with `rm -rf` before the new run begins.

### Logging

All log functions emit a `[HH:MM:SS]` prefix. Colour is enabled only when stdout is a terminal (`[[ -t 1 ]]`); otherwise all colour codes are empty strings (safe for CI/CD pipelines).

```bash
log_info()    { echo -e "[$(date '+%H:%M:%S')] ${BLUE}[INFO]${NC}    $*"; }
log_success() { echo -e "[$(date '+%H:%M:%S')] ${GREEN}[SUCCESS]${NC} $*"; }
log_error()   { echo -e "[$(date '+%H:%M:%S')] ${RED}[ERROR]${NC}   $*" >&2; }
log_warn()    { echo -e "[$(date '+%H:%M:%S')] ${YELLOW}[WARN]${NC}    $*"; }
log_phase()   { # Renders a box-drawing banner (╔═╗ / ║ / ╚═╝) around the phase label }
```

---

## Error Handling Strategy

- If any Phase 1 job fails, `wait_for_jobs` exits the script before Phase 2 (fail-fast).
- If any Phase 2 job fails, `wait_for_jobs` exits the script before Phase 3.
- All failed deployments are reported with the path to their log file.
- The script exits with a non-zero code if any phase fails.
- Unknown options cause an immediate error and print usage.

---

## Log File Structure

```
logs/
  2026-02-19T14-30-00/
    envs_dev_euw2_cell1000.log
    envs_dev_euw2_cell1001.log
    envs_networking_euw2_tgw.log
    envs_networking_euw2_tgw-vpc-atts.log
    envs_networking_global_tgw-peering.log
```

Slashes in directory paths are replaced by underscores to form log file names.

Log directories beyond the retention limit (10) are pruned at startup before the new run directory is created.

---

## Prerequisites / Assumptions

1. bash 4.0 or later is on `$PATH` (macOS ships bash 3.2 — use Homebrew bash).
2. `terraform` binary is on `$PATH`.
3. AWS credentials are configured (environment variables or instance profile).
4. All Terraform backends (S3 buckets) are pre-initialised (bootstrap already run).
5. The script is run from anywhere — it locates `REPO_ROOT` automatically.
6. The `envs/dev/<region>/<cell>/` and `envs/prod/<region>/<cell>/` naming convention is consistent.
7. `--auto-approve` is implicit for all applies (CI/CD or informed operator use).

---

## Full Deployment Timeline (estimated)

| Phase | Actions | Duration |
|-------|---------|----------|
| Phase 1 | All VPCs + all TGWs (parallel) | ~7 min (longest cell) |
| Wait | 30-second stabilisation | 30 sec |
| Phase 2 | All TGW-VPC Attachments (parallel per region) | ~3 min |
| Phase 3 | TGW Peering Attachments (sequential) | ~3 min per peering |
| **Total** | | **~14-15 min** |

Without parallelism (sequential), the same deployment would take approximately 10 min per cell + 2 min TGW + 3 min attachments = **30+ min for a single region with two cells**.

---

## Decisions (Agreed)

| # | Question | Decision |
|---|----------|----------|
| 1 | Peering directory path | Confirmed: `envs/networking/global/tgw-peering/` |
| 2 | `--auto-approve` safety | Always implicit — no extra flag required |
| 3 | Environment scope | Both `dev` and `prod` are deployed; `-e` accepts `dev`, `prod`, or `all` (default: `all`) |
| 4 | Variable files | Left to Terraform defaults — no special handling in the script |
| 5 | `--dry-run` output | Runs `terraform plan` with `tee` so output appears on console AND in the log file |
| 6 | Log retention | Keep last **10** run directories; auto-delete older ones at startup |
| 7 | Bash version | Requires bash 4.0+ (enforced); macOS users must install via Homebrew |
| 8 | Colour support | Auto-detected via `[[ -t 1 ]]`; disabled in non-interactive/CI environments |
| 9 | Job tracking | Associative array `JOB_MAP[pid]=dir` for traceability on failure |
| 10 | CI/CD pipeline integration | Descoped — will not be implemented at this time |

---

## Implementation Status

| Item | Status |
|------|--------|
| `scripts/deploy.sh` | Complete |
| `scripts/destroy.sh` (reverse teardown) | Complete |
| CI/CD pipeline integration (optional manual trigger) | Descoped — not planned |
| `docs/build.md` "Automated Deployment" section | Not started |

---

## Next Steps

1. ~~Create `scripts/deploy.sh` implementing the above design.~~ **Done.**
2. ~~Add a corresponding `scripts/destroy.sh` that runs in reverse order (peering first, then attachments, then TGWs, then VPCs).~~ **Done.**
3. ~~Add the script to the CI/CD pipeline as an optional manual trigger.~~ **Descoped — not planned.**
4. Document usage in `docs/build.md` under a new "Automated Deployment" section.
