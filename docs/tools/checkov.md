# Checkov

[Checkov](https://www.checkov.io/) is a static security analysis tool for Terraform. It scans HCL source files for misconfigurations and security policy violations — no AWS credentials required, no `terraform init` needed, no state read.

## What Checkov catches

| Category | Examples |
|----------|---------|
| Compute hardening | IMDSv2 not enforced, detailed monitoring disabled, EBS volumes not encrypted with a CMK |
| Network exposure | Security groups open to `0.0.0.0/0`, unrestricted ingress on sensitive ports |
| VPC controls | Flow Logs not enabled, default security group not restricted |
| Storage | S3 buckets missing access logging, encryption, versioning, or public-access blocks |
| IAM | Weak password policies (length, complexity, reuse, expiry) |
| Audit / compliance | CloudTrail not enabled or not validated, Security Hub not enabled, GuardDuty not enabled |

Checkov maps each finding to a check ID (e.g. `CKV_AWS_79`) and a severity level (LOW / MEDIUM / HIGH / CRITICAL). It does not make live API calls, so the same scan runs identically on a developer laptop and in CI.

## Configuration

The Checkov config lives at [`tools/.checkov.yaml`](../../tools/.checkov.yaml). Key settings:

- `framework: [terraform]` — restricts scanning to Terraform HCL only, skipping any CloudFormation or Kubernetes files that may exist in the repo.
- `compact: true` — omits the per-check code snippet from the output, keeping findings concise.
- `quiet: true` — suppresses passed checks; only failures are printed.
- `skip-check` — a curated list of check IDs that are suppressed repo-wide. Every entry carries an inline comment explaining the rationale. Skips fall into two categories:
  - **Intentional design choices** — e.g. `CKV_AWS_25` (SSH open to `0.0.0.0/0`) is correct for the bastion architecture used in this repo.
  - **Resource types not present** — e.g. all S3, IAM password-policy, CloudTrail, Security Hub, and GuardDuty checks are skipped because those resource types are not managed in this codebase.

## Running Checkov locally

### Via prek (pre-commit hook)

Checkov runs automatically on every commit via the `checkov` hook configured in [`tools/prek.yaml`](../../tools/prek.yaml).

To run the hook manually against all files:

```bash
prek -c tools/prek.yaml run --all-files checkov
```

To run against staged files only (same as what happens on commit):

```bash
prek -c tools/prek.yaml run checkov
```

### Directly via uv

```bash
uv run checkov --config-file tools/.checkov.yaml --directory .
```

This scans every Terraform file under the current directory using the repo-level config. Run from the repository root.

## CI job

The `checkov` job in [`.github/workflows/pipeline.yml`](../../.github/workflows/pipeline.yml) runs on every pull request. It:

1. Checks out the PR branch.
2. Installs Checkov via `uv` using the pinned version in `pyproject.toml`.
3. Runs `checkov --config-file tools/.checkov.yaml --directory .` from the repository root.
4. **Hard-fails** on any finding with severity HIGH or CRITICAL — the job exits non-zero and blocks the PR.
5. **Soft-fails** on LOW or MEDIUM findings — these are reported in the job output but do not block merging.

The job does not run on pushes to `main`.

## Updating the pinned version

Checkov is pinned in two places:

1. `pyproject.toml` — the version constraint used by `uv` to install Checkov locally and in CI.
2. `tools/prek.yaml` — the `rev` for the pre-commit hook (if Checkov is wired as a pre-commit hook rather than a direct `uv run` call).

To upgrade:

1. Check the [Checkov releases](https://github.com/bridgecrewio/checkov/releases) for the latest version.
2. Update the version in `pyproject.toml`.
3. Update the `rev` in `tools/prek.yaml` if applicable.
4. Run `uv sync` to regenerate the lockfile.
5. Run `prek -c tools/prek.yaml run --all-files checkov` locally to confirm the codebase is clean under the new version.
