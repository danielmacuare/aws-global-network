# Documentation vs Reality — Diff Report

> Source of truth: docs/ and specs/. This file documents where the actual code/config diverged from what the documentation stated.
> Generated: 2026-03-11 | Status: all items resolved

---

## A — Docs Conflicted with Actual Code (Fixed)

| # | File | Was | Fix applied |
|---|------|-----|-------------|
| A1 | `docs/dev/getting-started.md` | Terraform version listed as `>= 1.2.1` | Updated to `>= 1.14.4`; added `.terraform-version` / tfenv section |
| A2 | `docs/dev/tools/prek.md` | Only `terraform_tflint` hook documented | Added all 4 hooks: `terraform_validate`, `terraform_tflint`, `terraform_docs`, `checkov` |
| A3 | `docs/design/terraform-standards.md` | Referenced `tfsec`; used `tflint --recursive` (invalid flag) | Replaced with `checkov`/`prek`; corrected tflint command to use `--chdir` |
| A4 | `docs/dev/tools/ci-pipeline.md` | Job 3 described simple parallel init+validate | Updated to document the 3-step cache strategy (restore → pre-warm → parallel validate) and `TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE` |
| A5 | `docs/dev/tools/infracost.md` | Showed `REDACTED_ACCOUNT_ID` with no explanation | Added note explaining the placeholder and the `AWS_OIDC_ROLE_ARN` secret |

---

## B — Source Code Was Stale (Fixed)

The `sed` command that standardised `required_version` across the codebase missed two modules due to a spacing difference (`>=1.1.7` vs `>= 1.1.7`). The READMEs were accurate reflections of the source — the source `.tf` files were the problem.

| File | Was | Now |
|------|-----|-----|
| `modules/create-tgw/providers.tf` | `>= 1.1.7` | `>= 1.14.4` ✅ |
| `modules/create-tgw-vpc-attachment/providers.tf` | `>= 1.1.7` | `>= 1.14.4` ✅ |

READMEs regenerated via `prek -c tools/prek.yaml run --all-files terraform_docs`.

---

## C — Undocumented Code/Config (Fixed)

| # | What was missing | Fix applied |
|---|-----------------|-------------|
| C1 | `.terraform-version` file and tfenv not documented | Added section to `docs/dev/getting-started.md` |
| C2 | `scripts/tf_validate.py` not in tool docs | Created `docs/dev/tools/tf-validate.md`; added row to `docs/dev/tools/README.md` |
| C3 | Multi-platform lock file strategy not documented | Added section to `docs/dev/getting-started.md` explaining `terraform providers lock -platform=...` |
| C4 | `TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE` not documented | Explained in updated Job 3 section of `docs/dev/tools/ci-pipeline.md` |
| C5 | No consolidated tool version table | Added "Pinned Tool Versions" table to `docs/dev/tools/README.md` |

---

## D — Specs Inconsistencies (No changes — specs are historical records)

| # | Spec | Discrepancy | Decision |
|---|------|-------------|----------|
| D1 | `specs/13-tflint-pipeline-plan.md` | States tflint `v0.53.0`; actual CI uses `v0.61.0` | No change — specs are immutable historical records |
| D2 | `specs/10-fix-infracost-plan.md` | States 26 infracost directories; actual is 25 | No change — specs are immutable historical records |
| D3 | `specs/14-checkov-plan.md` | States 33 skip-checks; actual `.checkov.yaml` has 54 | No change — specs are immutable historical records |

---

## E — Codebase Inconsistency (Documented, not changed)

| # | Item | Notes |
|---|------|-------|
| E1 | `bootstrap/providers.tf` has `awscc >= 0.25.0` vs `>= 1.70.0` everywhere else | Bootstrap was created before the awscc constraint was standardised. The installed version (1.74.0) satisfies both constraints. No functional impact — left as-is. |
