# trivy

[Trivy](https://github.com/aquasecurity/trivy) is a security scanner that detects IaC misconfigurations in Terraform before they reach production. It requires no AWS credentials — all checks are static analysis against the configuration files.

## What Trivy catches

| Category | Examples |
|----------|---------|
| Overly permissive security groups | Ingress or egress rules open to `0.0.0.0/0` or `::/0` |
| Missing encryption | EBS volumes, S3 buckets, or RDS instances without encryption at rest |
| Public exposure | S3 buckets with public ACLs, EC2 instances with public IPs unnecessarily assigned |
| IAM issues | Overly broad IAM policies, wildcard actions or resources |
| Logging gaps | CloudTrail, VPC Flow Logs, or S3 access logging not enabled |

## Configuration

The Trivy config lives at [`tools/trivy.yaml`](../../tools/trivy.yaml). Key settings:

- `scan.scanners: [misconfig]` — runs only the IaC misconfiguration scanner, skipping vulnerability and secret scanning which are not relevant to Terraform source files.
- `severity: [HIGH, CRITICAL]` — only HIGH and CRITICAL findings fail the scan. MEDIUM and LOW findings are reported but do not block the pipeline or commit.
- `exit-code: 1` — Trivy exits non-zero when any findings at the configured severity levels are detected, causing CI and prek to fail.
- `skip-dirs` — excludes `.git`, `.terraform`, and `.tflint_plugins` from scanning to avoid noise from provider binaries and plugin caches.
- `skip-checks` — suppresses two checks that are intentionally violated by the non-production test EC2 bastion instances:
  - `AVD-AWS-0104`: ingress from `0.0.0.0/0` — required by the bastion design documented in [`specs/09-connectivity-test-plan.md`](../../specs/09-connectivity-test-plan.md).
  - `AVD-AWS-0107`: unrestricted egress — required for ICMP ping tests across TGW peerings.

## Running Trivy locally

### Via prek (pre-commit hook)

Trivy runs automatically on every commit via the `trivy` hook configured in [`tools/prek.yaml`](../../tools/prek.yaml). The hook uses `language: system` (a local hook), so Trivy must be installed on your machine (`brew install trivy`).

To run the hook manually against all files:

```bash
prek -c tools/prek.yaml run --all-files trivy
```

To run against staged files only (same as what happens on commit):

```bash
prek -c tools/prek.yaml run trivy
```

### Directly against the whole repository

```bash
trivy config --config tools/trivy.yaml .
```

### Directly against a single directory

```bash
trivy config --config tools/trivy.yaml envs/dev/euw2/cell1000
```

## CI job

The `trivy` job in [`.github/workflows/pipeline.yml`](../../.github/workflows/pipeline.yml) runs on every pull request. It:

1. Checks out the PR branch.
2. Runs the `aquasecurity/trivy-action@0.30.0` action pointing at `tools/trivy.yaml`.
3. Outputs findings in table format for readability in the GitHub Actions log.
4. Fails if any HIGH or CRITICAL misconfiguration is detected across the repository.

The job does not require AWS credentials. It does not run on pushes to `main`.

## Updating the Trivy version

1. Check the [Trivy releases](https://github.com/aquasecurity/trivy/releases) for the latest version.
2. Update the local installation: `brew upgrade trivy`.
3. Update the action pin (`aquasecurity/trivy-action@<version>`) in `.github/workflows/pipeline.yml`.
4. Run `prek -c tools/prek.yaml run --all-files trivy` locally to verify the codebase is clean under the new version.
