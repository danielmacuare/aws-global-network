# Feature 10 — Fix Infracost Integration

## Goal

Fix the existing Infracost GitHub Actions workflow so that it posts accurate cost-diff comments on every PR and updates the baseline on every push to `main`.

---

## Current Problems

The existing `.github/workflows/pipeline.yml` has the following issues:

1. **Only one directory scanned** — `TF_ROOT: envs/dev/euw2/cell1000/`. The repo has 35 Terraform directories across 4 regions, 3 envs (`dev`, `prod`, `networking`).
2. **SSH key step is broken** — the workflow tries to load `GIT_SSH_KEY` and `GIT_SSH_KEY_PASSPHRASE` secrets that don't exist. This will fail at the `add GIT_SSH_KEY` step before any cost estimate is generated.
3. **Comment behavior is `new`** — creates a new PR comment on every push, making PRs noisy. Should be `update`.
4. **No `infracost.yml` config file** — without a multi-project config, the CLI can only evaluate one directory at a time.
5. **Trigger on `push` to `main` is redundant** — the current single-job setup tries to compare against a base branch, which has no meaning on a push to `main`.
6. **Old `actions/checkout@v2`** — should use `v4` for compatibility with current runners.

---

## Solution

### 1. Create `infracost.yml` multi-project config

Create a top-level `infracost.yml` that lists all Terraform environments to scan. Skip `keypair` dirs and `test/` dirs (no cloud cost resources).

**Directories to include (26 total):**

```
envs/dev/euw1/cell3000
envs/dev/euw1/cell3001
envs/dev/euw2/cell1000
envs/dev/euw2/cell1001
envs/dev/use1/cell7000
envs/dev/use1/cell7001
envs/dev/usw2/cell5000
envs/dev/usw2/cell5001
envs/networking/euw1/tgw
envs/networking/euw1/tgw-vpc-atts
envs/networking/euw2/tgw
envs/networking/euw2/tgw-vpc-atts
envs/networking/global/tgw-peering
envs/networking/use1/tgw
envs/networking/use1/tgw-vpc-atts
envs/networking/usw2/tgw
envs/networking/usw2/tgw-vpc-atts
envs/prod/euw1/cell2000
envs/prod/euw1/cell2001
envs/prod/euw2/cell0000
envs/prod/euw2/cell0001
envs/prod/use1/cell6000
envs/prod/use1/cell6001
envs/prod/usw2/cell4000
envs/prod/usw2/cell4001
```

Format (infracost config v0.1):

```yaml
version: 0.1
projects:
  - path: envs/dev/euw1/cell3000
  - path: envs/dev/euw1/cell3001
  # ... (all 25 dirs)
```

### 2. Rewrite `.github/workflows/pipeline.yml`

Split into two jobs following the official infracost multi-project pattern:

#### Job 1: `infracost` (runs on `pull_request`)

Steps:
1. `infracost/actions/setup@v3` — install CLI with `INFRACOST_API_KEY`
2. `actions/checkout@v4` — checkout **base branch** (`github.event.pull_request.base.ref`)
3. `infracost breakdown --config-file=infracost.yml --format=json --out-file=/tmp/infracost-base.json`
4. `actions/checkout@v4` — checkout **PR branch**
5. `infracost diff --config-file=infracost.yml --format=json --compare-to=/tmp/infracost-base.json --out-file=/tmp/infracost.json`
6. `infracost comment github` — post/update PR comment with `--behavior=update`

Triggers: `pull_request` on `main`

Permissions: `pull-requests: write`

#### Job 2: `infracost-baseline` (runs on `push` to `main`)

Steps:
1. `infracost/actions/setup@v3`
2. `actions/checkout@v4`
3. `infracost breakdown --config-file=infracost.yml --format=json --out-file=/tmp/infracost-base.json`

This keeps the Infracost Cloud dashboard up to date after merges. No PR comment step needed.

---

## Files to Create / Modify

| File | Action | Description |
|------|--------|-------------|
| `infracost.yml` | **Create** | Multi-project config listing all 25 Terraform dirs |
| `.github/workflows/pipeline.yml` | **Rewrite** | Fix triggers, remove SSH steps, use config file, split PR vs push jobs |

---

## Key Decisions

- **Skip `keypair` dirs** — `aws_key_pair` is free; including them adds noise without meaningful cost.
- **Skip `envs/test/`** — test infra is ephemeral and not tracked.
- **`--behavior=update`** — single updating comment per PR (cleaner than `new`).
- **`INFRACOST_ENABLE_CLOUD: false`** — keep as-is; avoid sending data to SaaS dashboard unless opted in.
- **Use `infracost/actions/setup@v3`** — `v2` is outdated per current docs.
- **Remove SSH key steps** — no private Terraform modules in this repo.

---

## Acceptance Criteria

- [ ] Opening or updating a PR against `main` triggers the `infracost` job
- [ ] A cost-diff comment is posted/updated on the PR showing per-project breakdown
- [ ] Merging to `main` triggers the `infracost-baseline` job without errors
- [ ] No SSH key secrets are required
- [ ] All 25 Terraform directories are evaluated
