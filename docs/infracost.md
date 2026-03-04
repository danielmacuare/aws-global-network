# Infracost

Infracost estimates AWS costs from Terraform HCL — without applying changes or reading remote state.

## How it works

When a PR is opened, the pipeline runs two cost estimates and diffs them:

1. **Baseline** — checks out `main`, runs `terraform init -backend=false` + `terraform plan` on each module
2. **PR diff** — repeats against the PR branch, then compares both JSON outputs
3. **Comment** — posts (or updates) a single PR comment showing the cost delta per project

`-backend=false` means Terraform skips connecting to the S3 state backend entirely. Infracost only needs the provider credentials to parse resource definitions — it never reads or writes state.

## AWS authentication via OIDC

GitHub Actions does not use stored AWS keys. Instead it uses OpenID Connect (OIDC): the runner mints a short-lived JWT, exchanges it with AWS STS for temporary credentials scoped to the role `github-actions-infracost`, and those credentials expire when the job ends.

```
GitHub secret required: AWS_OIDC_ROLE_ARN
Role: arn:aws:iam::796324854413:role/github-actions-infracost
```

## Workflow diagram

```mermaid
sequenceDiagram
    participant PR as Pull Request
    participant GHA as GitHub Actions
    participant STS as AWS STS (OIDC)
    participant TF as Terraform (local)
    participant IC as Infracost CLI
    participant GH as GitHub API

    PR->>GHA: Opened / updated

    GHA->>STS: Exchange OIDC JWT for temp credentials
    STS-->>GHA: AssumeRoleWithWebIdentity<br/>(github-actions-infracost)

    GHA->>TF: checkout main + init -backend=false
    TF-->>GHA: providers downloaded (no state read)
    GHA->>IC: breakdown --config-file=infracost.yml
    IC-->>GHA: base-cost.json (current plan cost)

    GHA->>TF: checkout PR branch + init -backend=false
    TF-->>GHA: providers downloaded (no state read)
    GHA->>IC: diff --compare-to=base-cost.json
    IC-->>GHA: pr-cost.json (updated plan cost)

    GHA->>GH: infracost comment --behavior=update
    GH-->>PR: Cost delta comment (e.g. +$12.50/mo)
```
