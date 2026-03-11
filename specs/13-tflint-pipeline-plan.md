# Feature 13 — Add tflint to the CI/CD Pipeline

## Goal

Run `tflint` automatically on every pull request to catch Terraform errors, deprecated syntax, and AWS-specific rule violations across both `modules/` and `envs/` — enforcing code quality before changes reach `main`.

---

## Background

tflint is a Terraform linter that catches issues the `terraform validate` command misses:

- **Type errors and invalid values** — e.g. passing a string where a number is expected, using a variable that doesn't exist.
- **Deprecated syntax** — resource arguments that have been removed or renamed in newer provider versions.
- **AWS-specific rules** — via the `tflint-ruleset-aws` plugin, which encodes AWS API constraints: invalid instance types, invalid AMI IDs, unsupported region values, etc.
- **Best practices** — e.g. naming conventions, required tags, unused declarations.

This repo already has a `tools/.tflint.hcl` config that enables the AWS ruleset (plugin version `0.45.0`), and the `terraform_tflint` hook is already declared in `tools/prek.yaml` via `antonbabenko/pre-commit-terraform` rev `v1.105.0`. What is missing is the CI job in GitHub Actions that enforces linting on PRs.

---

## Solution Overview

Two integration points:

1. **Pre-commit hook** (local) — `terraform_tflint` already runs on every commit via `prek`, using `tools/.tflint.hcl` as the config. The hook configuration in `tools/prek.yaml` needs to be verified and updated to explicitly pass the config file path to tflint.
2. **CI job** (GitHub Actions) — a `tflint` job runs on PRs, installs tflint and the AWS ruleset, and lints every Terraform directory in `modules/` and `envs/`. The job fails if any lint error is found.

---

## Implementation Plan

### Step 1 — Verify and update `tools/prek.yaml`

The `terraform_tflint` hook is already present in `tools/prek.yaml` with no extra args. The hook calls tflint once per changed `.tf` file, but without an explicit `--config` flag it searches for `.tflint.hcl` walking up from the file's directory. Because `tools/.tflint.hcl` lives in `tools/` rather than the repo root, the hook will not find it automatically when linting files under `modules/` or `envs/`.

Update the hook entry to pass the config path explicitly:

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
```

`__GIT_WORKING_DIR__` is a token that `antonbabenko/pre-commit-terraform` expands to the repository root at runtime, making the path absolute regardless of which subdirectory is being linted.

After editing, reinstall hooks:

```bash
prek -c tools/prek.yaml install-hooks
```

Verify the hook works against all files:

```bash
prek -c tools/prek.yaml run --all-files terraform_tflint
```

### Step 2 — Review and harden `tools/.tflint.hcl`

The existing config enables the AWS plugin but has no explicit rule or tflint-core settings. Extend it to make CI behaviour deterministic:

```hcl
config {
  # Disable module inspection — no AWS credentials available in CI.
  # tflint will still lint all resource/variable declarations in the
  # current directory; it just won't follow module source references.
  call_module_type = "none"
}

plugin "aws" {
  enabled = true
  version = "0.45.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"

  # deep_check makes live AWS API calls to validate values (e.g. AMI IDs).
  # Disabled because CI has no real AWS credentials scoped for tflint.
  deep_check = false
}
```

`call_module_type = "none"` is the tflint v0.50+ equivalent of the deprecated `--module` flag. It tells tflint not to resolve module sources, which would otherwise fail in CI because the modules are local paths that require `terraform init` to be run first and there are no remote sources to fetch.

### Step 3 — Add a CI job to `pipeline.yml`

Add a new job `tflint` between the existing `terraform-docs` job and the `infracost-baseline` job. The job:

1. Checks out the PR branch.
2. Installs tflint using the official setup action.
3. Runs `tflint --init` to download the AWS ruleset plugin (using the version pinned in `.tflint.hcl`).
4. Discovers all Terraform directories under `modules/` and `envs/` and runs tflint against each.

```yaml
  # -----------------------------------------------------------------------
  # Job 3: Lint Terraform on PRs
  # -----------------------------------------------------------------------
  tflint:
    name: tflint
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'

    steps:
      - name: Checkout PR branch
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.ref }}

      - name: Install tflint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.53.0

      - name: Init tflint (download AWS ruleset plugin)
        run: tflint --init --config=tools/.tflint.hcl

      - name: Run tflint across all Terraform directories
        run: |
          set -euo pipefail
          FAILED=0
          while IFS= read -r dir; do
            echo "==> Linting: $dir"
            tflint --config="$GITHUB_WORKSPACE/tools/.tflint.hcl" --chdir="$dir" || FAILED=1
          done < <(find modules envs -name '*.tf' -not -path '*/.terraform/*' -printf '%h\n' | sort -u)
          exit $FAILED
```

Key points about the CI step design:

- `--config` receives an absolute path (`$GITHUB_WORKSPACE/tools/.tflint.hcl`) so it resolves correctly regardless of the `--chdir` value.
- `--chdir` changes tflint's working directory per-invocation, which is how tflint is designed to be run against a directory (not a single file).
- The `find` command skips `.terraform/` subdirectories to avoid linting cached provider plugin code.
- `FAILED=1` pattern accumulates failures so all directories are linted before the job exits, giving complete feedback in one run rather than stopping at the first error.
- `set -euo pipefail` ensures the step fails on unexpected shell errors.

### Step 4 — Add `docs/tools/tflint.md`

Create a short reference document at `docs/tools/tflint.md` (following the same pattern as `infracost.md` and `prek.md`) covering:

- What tflint does and what it catches that `terraform validate` misses.
- How the pre-commit hook runs locally via prek.
- How the CI job enforces linting on PRs.
- How to run tflint manually against a single directory.
- How to update the AWS ruleset plugin version.

### Step 5 — Update `specs/index.md`

Mark feature 13 as Complete once all steps are merged.

---

## Which Directories to Lint

**Both `modules/` and `envs/` are linted.**

Rationale:

- `modules/` contains the reusable building blocks (create-vpc, create-tgw, create-ec2, etc.). These are the highest-value lint targets because bugs here affect every environment that calls them.
- `envs/` contains flat root modules that call those reusable modules. They hold resource arguments, variable values, and `locals.tf` logic that is equally susceptible to type errors, invalid AWS values, and deprecated syntax. With 32+ env directories across 4 regions, 2 environments, and multiple cell/keypair/networking stacks, skipping them would leave a large surface area unchecked.
- `envs/test/` is intentionally included — it contains throw-away test stacks but is still real Terraform code that should not contain lint errors.

The only directories skipped are `.terraform/` subdirectories (cached provider plugins), which are not source code.

---

## Handling the AWS Ruleset Without Real Credentials

The AWS ruleset plugin has two distinct modes:

| Mode | What it checks | Requires AWS API? |
|------|---------------|-------------------|
| Static analysis | Resource argument types, valid enum values, deprecated arguments | No |
| Deep check | Live resource existence (e.g. AMI ID exists in the account) | Yes |

CI uses static analysis only (`deep_check = false` in `.tflint.hcl`). This still catches the most common and valuable errors: invalid instance types, unsupported region strings, deprecated argument names, type mismatches. Deep check is left for local developer runs where AWS credentials are available.

`call_module_type = "none"` prevents tflint from trying to resolve module sources. Without this, tflint would attempt to read module metadata which requires `terraform init` to have been run — an unreasonable requirement in a lint-only CI job where no state or backend is involved. The pipeline already sets `TF_CLI_ARGS_init: "-backend=false"` as an env var for Terraform itself; tflint is independent and needs its own guard.

---

## Files to Create / Modify

| File | Action | Description |
|------|--------|-------------|
| `tools/prek.yaml` | **Edit** | Add `--args=--config=__GIT_WORKING_DIR__/tools/.tflint.hcl` to the `terraform_tflint` hook |
| `tools/.tflint.hcl` | **Edit** | Add `config {}` block with `call_module_type = "none"` and `deep_check = false` in the `plugin "aws"` block |
| `.github/workflows/pipeline.yml` | **Edit** | Add `tflint` job (install tflint, init plugin, run against all `modules/` and `envs/` directories) |
| `docs/tools/tflint.md` | **Create** | Reference doc for the tool |
| `specs/index.md` | **Edit** | Mark feature 13 Complete |

---

## Key Decisions

- **Lint both `modules/` and `envs/`** — `envs/` contains 32+ root modules with real resource arguments; skipping them would leave the majority of the codebase unchecked. The overhead is acceptable since the CI job runs in parallel with other jobs.
- **`deep_check = false`** — CI has no AWS credentials scoped for tflint API calls. Static analysis catches the majority of actionable lint errors without credentials.
- **`call_module_type = "none"`** — avoids the requirement for `terraform init` to be run before linting, keeping the CI job fast and self-contained.
- **Absolute `--config` path in CI** — using `$GITHUB_WORKSPACE/tools/.tflint.hcl` ensures the config is always found regardless of the `--chdir` value passed per directory.
- **`__GIT_WORKING_DIR__` token in prek.yaml** — the supported way to pass an absolute config path from the `antonbabenko/pre-commit-terraform` hook without hardcoding a machine-specific path.
- **Pin tflint to `v0.53.0` in CI** — consistent with the AWS ruleset version `0.45.0` already pinned in `.tflint.hcl`. Pinning prevents silent breakage if tflint releases a version with changed rule defaults.
- **`terraform-linters/setup-tflint@v4`** — the official GitHub Action for installing tflint; no need to manually download and extract a binary.
- **Accumulate failures across directories** — the `FAILED` pattern ensures all directories are linted and all errors are reported before the job exits, rather than stopping at the first failing directory.
- **`tools/.tflint.hcl` location** — the config already lives in `tools/` alongside `prek.yaml` and `infracost.yml`. It stays there; the CI job and hook both reference it by explicit path.

---

## Acceptance Criteria

- [ ] `prek -c tools/prek.yaml run --all-files terraform_tflint` runs cleanly with no errors on the current codebase
- [ ] `tools/.tflint.hcl` contains a `config {}` block with `call_module_type = "none"` and `deep_check = false` in the `plugin "aws"` block
- [ ] The `tflint` CI job appears in `pipeline.yml` and is gated on `github.event_name == 'pull_request'`
- [ ] A PR that introduces a lint error (e.g. an invalid `instance_type` value) causes the `tflint` CI job to fail
- [ ] A PR with no lint errors passes the `tflint` CI job
- [ ] All directories under `modules/` and `envs/` (excluding `.terraform/` subdirectories) are linted by the CI job
- [ ] `docs/tools/tflint.md` exists and documents local and CI usage
- [ ] `specs/index.md` marks feature 13 as Complete
