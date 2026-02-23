#!/usr/bin/env bash
# =============================================================================
# destroy.sh — Parallel teardown of TGW Attachments, TGWs, and VPCs
# =============================================================================
#
# Usage:
#   ./scripts/destroy.sh [OPTIONS]
#
# Options:
#   -e, --environment   Environments to destroy: dev, prod, or all (default: all)
#   -r, --regions       Comma-separated list of regions (default: all discovered)
#   --dry-run           Run terraform plan -destroy to preview what would be removed
#   --skip-peering      Skip Phase 1 (TGW Peering Attachment teardown)
#   -h, --help          Show this help message
#
# Destruction phases (reverse of deployment):
#   Phase 1 (sequential): TGW Peering Attachments  — must go first (depend on TGWs)
#   Phase 2 (parallel)  : TGW-VPC Attachments      — one job per region
#   Wait                : 30 s for TGW propagation
#   Phase 3 (parallel)  : All regional TGWs + all VPC cells
#   Phase 4 (parallel)  : SSH Key Pairs             — destroyed last (created first)
#
# Requirements: bash 4.0+, terraform on $PATH, AWS credentials configured.
# Run from repository root (the script enforces this).
# =============================================================================

set -eo pipefail

# ── Bash version guard ────────────────────────────────────────────────────────
if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
  echo "ERROR: destroy.sh requires bash 4.0 or later (current: ${BASH_VERSION})." >&2
  exit 1
fi

# ── Paths & constants ─────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date '+%Y-%m-%dT%H-%M-%S')"
LOG_DIR="${REPO_ROOT}/logs/${TIMESTAMP}"
LOG_RETENTION=10
TGW_STABILISE_WAIT=30

# ── Colours ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# ── Defaults ──────────────────────────────────────────────────────────────────
ENVIRONMENTS=("dev" "prod")
REGIONS=()
DRY_RUN=false
SKIP_PEERING=false

# ── Logging ───────────────────────────────────────────────────────────────────
log_info()    { echo -e "[$(date '+%H:%M:%S')] ${BLUE}[INFO]${NC}    $*"; }
log_success() { echo -e "[$(date '+%H:%M:%S')] ${GREEN}[SUCCESS]${NC} $*"; }
log_error()   { echo -e "[$(date '+%H:%M:%S')] ${RED}[ERROR]${NC}   $*" >&2; }
log_warn()    { echo -e "[$(date '+%H:%M:%S')] ${YELLOW}[WARN]${NC}    $*"; }
log_phase()   {
  local msg="  $*  "
  local len="${#msg}"
  local border
  border="$(printf '═%.0s' $(seq 1 "$len"))"
  echo -e "\n${BOLD}${CYAN}╔${border}╗${NC}"
  echo -e "${BOLD}${CYAN}║${msg}║${NC}"
  echo -e "${BOLD}${CYAN}╚${border}╝${NC}\n"
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Destroys TGW Attachments, TGWs, and VPCs in reverse dependency order.

Options:
  -e, --environment   Environments: dev, prod, or all (default: all)
  -r, --regions       Comma-separated regions, e.g. euw2,use1 (default: all)
  --dry-run           Run terraform plan -destroy to preview what would be removed
  --skip-peering      Skip Phase 1 (TGW Peering Attachment teardown)
  -h, --help          Show this help

Examples:
  $(basename "$0")                    # Destroy all envs, all regions
  $(basename "$0") -e dev             # Destroy dev only
  $(basename "$0") -r euw2            # Destroy eu-west-2 only
  $(basename "$0") --dry-run          # Preview all destructions
  $(basename "$0") -e prod --dry-run  # Preview prod destructions
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--environment)
      case "$2" in
        all)  ENVIRONMENTS=("dev" "prod") ;;
        dev)  ENVIRONMENTS=("dev") ;;
        prod) ENVIRONMENTS=("prod") ;;
        *)    log_error "Unknown environment '$2'. Use: dev, prod, or all."; exit 1 ;;
      esac
      shift 2 ;;
    -r|--regions)
      IFS=',' read -ra REGIONS <<< "$2"
      shift 2 ;;
    --dry-run)      DRY_RUN=true;       shift ;;
    --skip-peering) SKIP_PEERING=true;  shift ;;
    -h|--help)      usage; exit 0 ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1 ;;
  esac
done

# ── Region filter ─────────────────────────────────────────────────────────────
# Returns 0 (true) if the given region should be included.
region_included() {
  local region="$1"
  [[ ${#REGIONS[@]} -eq 0 ]] && return 0
  local r
  for r in "${REGIONS[@]}"; do
    [[ "$r" == "$region" ]] && return 0
  done
  return 1
}

# ── Terraform runner ──────────────────────────────────────────────────────────
# Runs terraform init + destroy (or plan -destroy in dry-run mode) in the given directory.
# Intended to be called as a background job.
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
    log_info "Planning destroy: ${rel_dir}"
    (
      cd "$abs_dir"
      terraform init -input=false >> "$log_file" 2>&1
      terraform plan -destroy -input=false 2>&1 | tee -a "$log_file"
    ) || rc=$?
  else
    log_info "Destroying: ${rel_dir}"
    (
      cd "$abs_dir"
      terraform init -input=false >> "$log_file" 2>&1
      terraform destroy -auto-approve -input=false >> "$log_file" 2>&1
    ) || rc=$?
  fi

  if [[ $rc -eq 0 ]]; then
    log_success "Done: ${rel_dir}"
  else
    log_error "FAILED: ${rel_dir} — see ${log_file}"
  fi
  return $rc
}

# ── Job tracking ──────────────────────────────────────────────────────────────
declare -A JOB_MAP=()

# Waits for all tracked background jobs; exits the script if any failed.
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

  # Reset for next phase
  JOB_MAP=()

  if [[ $failed -gt 0 ]]; then
    log_error "${phase_label} — ${failed} job(s) failed. Aborting."
    exit 1
  fi
}

# ── Log rotation ──────────────────────────────────────────────────────────────
rotate_logs() {
  local logs_base="${REPO_ROOT}/logs"
  [[ -d "$logs_base" ]] || return 0

  local dirs=("${logs_base}"/*)
  local count="${#dirs[@]}"

  if [[ $count -ge $LOG_RETENTION ]]; then
    local to_delete=$(( count - LOG_RETENTION + 1 ))
    local i
    for (( i=0; i<to_delete; i++ )); do
      log_warn "Removing old log dir: ${dirs[$i]}"
      rm -rf "${dirs[$i]}"
    done
  fi
}

# ── Discovery ─────────────────────────────────────────────────────────────────
# Discovers VPC cell directories: envs/{dev,prod}/<region>/<cell>/
discover_vpc_cells() {
  local env region region_dir cell_dir
  for env in "${ENVIRONMENTS[@]}"; do
    local env_dir="${REPO_ROOT}/envs/${env}"
    [[ -d "$env_dir" ]] || continue
    for region_dir in "${env_dir}"/*/; do
      [[ -d "$region_dir" ]] || continue
      region="$(basename "$region_dir")"
      region_included "$region" || continue
      for cell_dir in "${region_dir}"*/; do
        [[ -d "$cell_dir" ]] || continue
        [[ "$(basename "$cell_dir")" == "keypair" ]] && continue
        ls "${cell_dir}"*.tf >/dev/null 2>&1 || continue
        echo "envs/${env}/${region}/$(basename "$cell_dir")"
      done
    done
  done
}

# Discovers dedicated key pair environments: envs/{dev,prod}/<region>/keypair/
discover_keypairs() {
  local env region region_dir keypair_dir
  for env in "${ENVIRONMENTS[@]}"; do
    local env_dir="${REPO_ROOT}/envs/${env}"
    [[ -d "$env_dir" ]] || continue
    for region_dir in "${env_dir}"/*/; do
      [[ -d "$region_dir" ]] || continue
      region="$(basename "$region_dir")"
      region_included "$region" || continue
      keypair_dir="${region_dir}keypair"
      [[ -d "$keypair_dir" ]] || continue
      ls "${keypair_dir}"/*.tf >/dev/null 2>&1 || continue
      echo "envs/${env}/${region}/keypair"
    done
  done
}

# Discovers regional TGW directories: envs/networking/<region>/tgw/
discover_tgws() {
  local region region_dir tgw_dir
  for region_dir in "${REPO_ROOT}/envs/networking"/*/; do
    [[ -d "$region_dir" ]] || continue
    region="$(basename "$region_dir")"
    [[ "$region" == "global" ]] && continue
    region_included "$region" || continue
    tgw_dir="${region_dir}tgw"
    [[ -d "$tgw_dir" ]] || continue
    ls "${tgw_dir}"/*.tf >/dev/null 2>&1 || continue
    echo "envs/networking/${region}/tgw"
  done
}

# Discovers TGW-VPC Attachment directories: envs/networking/<region>/tgw-vpc-atts/
discover_tgw_vpc_atts() {
  local region region_dir att_dir
  for region_dir in "${REPO_ROOT}/envs/networking"/*/; do
    [[ -d "$region_dir" ]] || continue
    region="$(basename "$region_dir")"
    [[ "$region" == "global" ]] && continue
    region_included "$region" || continue
    att_dir="${region_dir}tgw-vpc-atts"
    [[ -d "$att_dir" ]] || continue
    ls "${att_dir}"/*.tf >/dev/null 2>&1 || continue
    echo "envs/networking/${region}/tgw-vpc-atts"
  done
}

# Discovers TGW Peering directory: envs/networking/global/tgw-peering/
discover_tgw_peering() {
  local peering_dir="${REPO_ROOT}/envs/networking/global/tgw-peering"
  [[ -d "$peering_dir" ]] && ls "${peering_dir}"/*.tf >/dev/null 2>&1 && \
    echo "envs/networking/global/tgw-peering"
  return 0
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  cd "$REPO_ROOT"
  mkdir -p "$LOG_DIR"
  rotate_logs

  log_phase "AWS Global Network — Parallel Teardown"
  log_info "Repo root    : ${REPO_ROOT}"
  log_info "Log dir      : ${LOG_DIR}"
  log_info "Environments : ${ENVIRONMENTS[*]}"
  log_info "Regions      : ${REGIONS[*]:-all}"
  log_info "Dry run      : ${DRY_RUN}"
  log_info "Skip peering : ${SKIP_PEERING}"

  # ── Discover all targets ────────────────────────────────────────────────────
  mapfile -t KEYPAIRS    < <(discover_keypairs)
  mapfile -t VPC_CELLS   < <(discover_vpc_cells)
  mapfile -t TGWS        < <(discover_tgws)
  mapfile -t TGW_ATTS    < <(discover_tgw_vpc_atts)
  mapfile -t TGW_PEERING < <(discover_tgw_peering)

  log_info "Found: ${#KEYPAIRS[@]} key pair env(s) | ${#VPC_CELLS[@]} VPC cell(s) | ${#TGWS[@]} TGW(s) | ${#TGW_ATTS[@]} attachment group(s) | ${#TGW_PEERING[@]} peering group(s)"

  if [[ ${#KEYPAIRS[@]} -eq 0 && ${#VPC_CELLS[@]} -eq 0 && ${#TGWS[@]} -eq 0 ]]; then
    log_warn "Nothing to destroy. Check --environment and --regions filters."
    exit 0
  fi

  # ── Phase 1: TGW Peering Attachments (sequential) ──────────────────────────
  if [[ "$SKIP_PEERING" == "false" && ${#TGW_PEERING[@]} -gt 0 ]]; then
    log_phase "Phase 1 — TGW Peering Attachments (sequential)"

    local dir
    for dir in "${TGW_PEERING[@]}"; do
      run_terraform "$dir"
    done

    log_success "Phase 1 complete."
  else
    log_warn "No TGW Peering directories found (or --skip-peering set) — skipping Phase 1."
  fi

  # ── Phase 2: TGW-VPC Attachments in parallel (one per region) ──────────────
  if [[ ${#TGW_ATTS[@]} -gt 0 ]]; then
    log_phase "Phase 2 — TGW-VPC Attachments (parallel)"

    local dir
    for dir in "${TGW_ATTS[@]}"; do
      run_terraform "$dir" &
      JOB_MAP[$!]="$dir"
    done

    wait_for_jobs "Phase 2"
    log_success "Phase 2 complete."
  else
    log_warn "No TGW-VPC Attachment directories found — skipping Phase 2."
  fi

  # ── 30-second TGW stabilisation wait ───────────────────────────────────────
  if [[ ${#TGW_ATTS[@]} -gt 0 ]]; then
    log_info "Waiting ${TGW_STABILISE_WAIT}s for TGW to stabilise before destroying TGWs and VPCs..."
    sleep "$TGW_STABILISE_WAIT"
  fi

  # ── Phase 3: TGWs + VPCs in parallel ───────────────────────────────────────
  log_phase "Phase 3 — TGWs + VPCs (parallel)"

  local dir
  for dir in "${TGWS[@]}" "${VPC_CELLS[@]}"; do
    run_terraform "$dir" &
    JOB_MAP[$!]="$dir"
  done

  wait_for_jobs "Phase 3"
  log_success "Phase 3 complete."

  # ── Phase 4: SSH Key Pairs (parallel) — destroyed last ─────────────────────
  if [[ ${#KEYPAIRS[@]} -gt 0 ]]; then
    log_phase "Phase 4 — SSH Key Pairs (parallel — destroyed last)"

    local dir
    for dir in "${KEYPAIRS[@]}"; do
      run_terraform "$dir" &
      JOB_MAP[$!]="$dir"
    done

    wait_for_jobs "Phase 4"
    log_success "Phase 4 complete."
  fi

  # ── Done ───────────────────────────────────────────────────────────────────
  log_phase "Teardown Complete"
  log_success "All phases finished. Logs: ${LOG_DIR}"
}

main "$@"
