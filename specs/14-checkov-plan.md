> **Amendment (Feature 16):** The `pip install checkov==3.2.434` step in the CI job below has been superseded by the uv-based installation defined in [Feature 16 — Standardise Python Dependency Management on uv](./16-uv-python-plan.md). When implementing this feature, use `astral-sh/setup-uv@v5` + `uv sync --group dev` + `uv run checkov` instead of the pip install step.

# Feature 14 — Add Checkov to the CI/CD Pipeline

## Goal

Run [Checkov](https://www.checkov.io/) static security analysis against all Terraform code on every pull request and as a pre-commit hook locally. Any finding at HIGH or CRITICAL severity blocks the PR. Irrelevant checks (those that require live AWS API access or that test production-hardening controls not applicable to this network test infrastructure) are skipped via a config file.

---

## Background

The repo contains six reusable modules and sixteen environment root modules spanning four AWS regions (eu-west-2, eu-west-1, us-west-2, us-east-1). The Terraform code provisions:

- VPCs with public/private subnets, internet gateways, and egress-only internet gateways
- Transit Gateways and TGW-VPC attachments for full-mesh inter-region routing
- Bastion EC2 instances (Ubuntu 24.04, public subnet, SSH open to `0.0.0.0/0` — intentional for a network connectivity test lab)
- Private EC2 instances for ping testing
- Security groups with broad ingress from TGW supernets

tflint (feature 13) and terraform-docs (feature 12) are already enforced in CI. Checkov adds the security-posture layer: it scans Terraform plan/config statically without needing AWS credentials, making it a natural fit for the existing credential-free CI pattern established by tflint.

Certain Checkov rules are intentionally not applicable to this repo:

- Checks that require VPC Flow Logs (`CKV2_AWS_11`) — Flow Logs add cost and are unnecessary for a network test lab.
- Checks that require EBS encryption via KMS CMK (`CKV_AWS_189`) — root volumes are encrypted with the default AWS-managed key, which is sufficient for test infrastructure.
- Checks for IMDSv2 enforcement (`CKV_AWS_79`) — bastion instances are short-lived and managed by operators; IMDSv2 is not relevant to this use case.
- Checks for EC2 detailed monitoring (`CKV_AWS_8`) — dev/test instances; CloudWatch detailed monitoring adds unnecessary cost.
- Checks requiring SSH restricted from `0.0.0.0/0` (`CKV_AWS_25`) — the bastion security group intentionally permits SSH from any source; that is the design of a public bastion host.
- Checks for S3 bucket hardening (`CKV_AWS_18`, `CKV_AWS_19`, `CKV_AWS_20`, `CKV_AWS_21`, `CKV2_AWS_6`, `CKV2_AWS_62`) — this repo contains no S3 resources.
- Checks for IAM password policy (`CKV_AWS_9` through `CKV_AWS_16`) — no IAM resources are managed in this repo.
- Checks for CloudTrail (`CKV_AWS_35`, `CKV_AWS_36`, `CKV_AWS_67`) — account-level controls outside the scope of this repo.
- Checks for Security Hub and GuardDuty (`CKV_AWS_66`, `CKV2_AWS_48`) — account-level controls not managed here.
- Checks for EBS snapshot public access (`CKV_AWS_32`) — no snapshots are managed here.

---

## Solution Overview

Three integration points:

1. **Config file** (`tools/.checkov.yaml`) — single source of truth for framework, output flags, and the skip-check list. Both the pre-commit hook and the CI job reference it via `--config-file`.
2. **Pre-commit hook** (local) — `checkov` runs on every commit via `prek` using the `bridgecrewio/checkov` hook, scanning staged Terraform files.
3. **CI job** (GitHub Actions) — a `checkov` job runs on PRs, installs checkov via pip, and runs it across the full repo using the shared config file.

---

## Implementation Plan

### Step 1 — Create `tools/.checkov.yaml`

Create the Checkov config file at `tools/.checkov.yaml`. Placing it alongside `.tflint.hcl` and `infracost.yml` keeps all tool configs in one location.

```yaml
framework:
  - terraform

compact: true
quiet: true

skip-check:
  # --- Intentional design choices for network test infrastructure ---
  - CKV_AWS_25    # SG: SSH open to 0.0.0.0/0 — bastion design is intentional
  - CKV_AWS_24    # SG: Telnet open — not present but pre-emptive skip for all SG open-port checks not applicable here
  # --- EC2 hardening not applicable to short-lived test instances ---
  - CKV_AWS_79    # EC2: IMDSv2 not enforced
  - CKV_AWS_8     # EC2: detailed monitoring disabled
  - CKV_AWS_189   # EC2: EBS not encrypted with CMK (default key encryption is used)
  # --- VPC / networking controls not required for test lab ---
  - CKV2_AWS_11   # VPC: Flow Logs not enabled
  - CKV2_AWS_12   # VPC: default security group not restricted (not managed here)
  # --- Resource types not present in this repo ---
  - CKV_AWS_18    # S3: access logging
  - CKV_AWS_19    # S3: encryption
  - CKV_AWS_20    # S3: public access - READ
  - CKV_AWS_21    # S3: versioning
  - CKV2_AWS_6    # S3: public access block
  - CKV2_AWS_62   # S3: event notifications
  - CKV_AWS_9     # IAM: password policy - minimum length
  - CKV_AWS_10    # IAM: password policy - symbols
  - CKV_AWS_11    # IAM: password policy - numbers
  - CKV_AWS_12    # IAM: password policy - uppercase
  - CKV_AWS_13    # IAM: password policy - lowercase
  - CKV_AWS_14    # IAM: password policy - reuse
  - CKV_AWS_15    # IAM: password policy - expiry
  - CKV_AWS_16    # IAM: password policy - age
  - CKV_AWS_35    # CloudTrail: logging enabled
  - CKV_AWS_36    # CloudTrail: log file validation
  - CKV_AWS_67    # CloudTrail: CloudWatch integration
  - CKV_AWS_66    # Security Hub not enabled
  - CKV2_AWS_48   # GuardDuty not enabled
  - CKV_AWS_32    # EBS snapshot not public
```

### Step 2 — Add the pre-commit hook to `tools/prek.yaml`

The `bridgecrewio/checkov` repo provides a `checkov` hook id. Add it as a new `repo` block in `tools/prek.yaml`. The hook passes `--config-file` pointing to the shared config.

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.105.0
    hooks:
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/tools/.tflint.hcl
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-apache-2-license-copyright-header=false
          - --hook-config=--create-file-if-not-exist=true

  - repo: https://github.com/bridgecrewio/checkov
    rev: 3.2.434
    hooks:
      - id: checkov
        args:
          - --config-file=tools/.checkov.yaml
```

The rev `3.2.434` is the latest stable release as of 2026-03-07. Pin it to a specific tag so hook behaviour is reproducible. Update by bumping the rev and running `prek -c tools/prek.yaml install-hooks`.

After editing `tools/prek.yaml`, reinstall hooks:

```bash
prek -c tools/prek.yaml install-hooks
```

Run the hook once against all files to verify the baseline is clean:

```bash
prek -c tools/prek.yaml run --all-files checkov
```

Fix any findings before proceeding. The skip-check list in Step 1 should suppress all known false positives; adjust it if additional irrelevant checks surface.

### Step 3 — Add a `checkov` CI job to `pipeline.yml`

Add a new job after the existing `tflint` job. The job installs checkov via pip (no special action needed — the PyPI package is self-contained), then runs it across all Terraform directories using the shared config file.

```yaml
# -----------------------------------------------------------------------
# Job 5: Static security analysis on PRs
# -----------------------------------------------------------------------
checkov:
  name: Checkov
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'

  steps:
    - name: Checkout PR branch
      uses: actions/checkout@v4
      with:
        ref: ${{ github.event.pull_request.head.ref }}

    - name: Install Checkov
      run: pip install checkov==3.2.434

    - name: Run Checkov
      run: |
        checkov \
          --config-file tools/.checkov.yaml \
          --directory . \
          --soft-fail-on LOW,MEDIUM \
          --hard-fail-on HIGH,CRITICAL
```

Key flags:
- `--config-file tools/.checkov.yaml` — loads framework, compact, quiet, and skip-check from the shared config.
- `--directory .` — scans the entire repo; Checkov's `--framework terraform` filter (set in the config file) restricts it to `.tf` files.
- `--soft-fail-on LOW,MEDIUM` — LOW and MEDIUM findings are reported but do not block the PR.
- `--hard-fail-on HIGH,CRITICAL` — HIGH or CRITICAL findings cause a non-zero exit, failing the job and blocking the PR.

No AWS credentials are required. Checkov static analysis is purely file-based.

### Step 4 — Create `docs/tools/checkov.md`

Create a reference document at `docs/tools/checkov.md` following the same structure as `docs/tools/tflint.md`.

Content to cover:
- What Checkov is and what it catches (misconfigurations, security anti-patterns in Terraform)
- The config file location and key settings
- How to run it locally via prek
- How to run it directly against the whole repo or a single directory
- How the CI job works and what causes it to fail
- How to update the pinned version

### Step 5 — Update `specs/index.md`

Add feature 14 to the index table with status "In planning", then mark it Complete once all steps are merged.

---

## Files to Create / Modify

| File | Action | Description |
|------|--------|-------------|
| `tools/.checkov.yaml` | **Create** | Checkov config: framework, compact, quiet, skip-check list |
| `tools/prek.yaml` | **Edit** | Add `bridgecrewio/checkov` repo block with pinned rev |
| `.github/workflows/pipeline.yml` | **Edit** | Add `checkov` job (Job 5) that hard-fails on HIGH/CRITICAL |
| `docs/tools/checkov.md` | **Create** | Reference doc for the tool |
| `specs/index.md` | **Edit** | Add feature 14 with status "In planning" |

---

## Key Decisions

- **Config file in `tools/`** — consistent with `.tflint.hcl` and `infracost.yml`; a single authoritative source for both local and CI invocations. Avoids duplicating flags between `prek.yaml` and `pipeline.yml`.
- **Severity split: soft-fail LOW/MEDIUM, hard-fail HIGH/CRITICAL** — LOW and MEDIUM findings are visible in the CI log for awareness but do not block merges. Only actionable security issues block the PR. This avoids alert fatigue on test infrastructure while still enforcing the most serious checks.
- **pip install (not a GitHub Action)** — there is no official `bridgecrewio/checkov-action` that is as actively maintained as the PyPI package. Using `pip install checkov==3.2.434` gives a pinned, reproducible install with no extra abstraction. This is consistent with the tflint job, which uses a setup action, but simpler since checkov has no init step.
- **`--directory .` not per-directory** — unlike tflint (which must be run per directory because it has no recursive mode), Checkov natively recurses from a root directory and resolves cross-file references within each Terraform root module. Running it once from the repo root is cleaner and faster.
- **`bridgecrewio/checkov` pre-commit hook** — uses the same Python package under the hood. The hook runs checkov only against staged `.tf` files, keeping local commits fast. The `--config-file` arg ensures parity with CI.
- **No `--framework` flag in hook args** — the `framework` key in `tools/.checkov.yaml` is read by the hook automatically via `--config-file`. This avoids duplicating the flag.
- **Pinned rev `3.2.434`** — Checkov releases frequently. Pinning prevents unexpected behaviour changes between commits. Update the pin in both `prek.yaml` and `pipeline.yml` together to keep local and CI environments aligned.
- **Skip-check rationale documented in config** — every skipped check has an inline comment explaining why. This prevents future contributors from blindly removing skips or wondering why the list exists.

---

## Acceptance Criteria

- [ ] `tools/.checkov.yaml` exists with `framework: terraform`, `compact: true`, `quiet: true`, and a documented `skip-check` list
- [ ] `prek -c tools/prek.yaml install-hooks` completes without error
- [ ] `prek -c tools/prek.yaml run --all-files checkov` runs cleanly with no HIGH or CRITICAL findings
- [ ] The `checkov` CI job appears in `pipeline.yml` and runs on `pull_request` only
- [ ] A PR that introduces a HIGH-severity misconfiguration (e.g. an unencrypted root block device without the `encrypted = true` flag) causes the `checkov` CI job to fail
- [ ] A PR with no HIGH or CRITICAL findings passes the `checkov` CI job; LOW/MEDIUM findings are visible in the log but do not block
- [ ] `docs/tools/checkov.md` exists and documents local and CI usage, the config file, and how to update the version pin
- [ ] `specs/index.md` lists feature 14
