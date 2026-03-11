# 17 — Docs Reorganization

## Context
The repo's documentation is scattered across `docs/`, `docs/tools/`, and `specs/`. The goal is a clean two-folder structure so it's obvious where any doc belongs:
- `docs/design/` — architecture, infrastructure decisions, Terraform standards
- `docs/dev/` — operational guides, tool usage, troubleshooting

The root `README.md` becomes the entry point with links to everything.

---

## Target Structure

```
docs/
├── design/
│   ├── network-design.md          ← from specs/DESIGN.md
│   ├── tgws.md                    ← already here, no change
│   ├── tgw-vpc-attachments.md     ← from docs/tgw-vpc-peering-attachments.md
│   ├── ipv6-assignment.md         ← from docs/ipv6-assignment.md
│   ├── tagging-strategy.md        ← from docs/tagging-strategy.md
│   └── terraform-standards.md     ← from specs/TERRAFORM.md + merge specs/30-others.md
└── dev/
    ├── getting-started.md         ← from docs/getting-started.md
    ├── deployment.md              ← from docs/deployment.md + merge docs/build.md
    ├── key-pairs.md               ← from docs/key-pairs.md
    ├── ngw-timeout.md             ← from docs/ngw-timeout.md
    ├── connectivity/
    │   ├── README.md              ← new index
    │   ├── conn-results-summary.md ← from specs/conn-results-summary.md
    │   ├── conn-results-euw1.md   ← from specs/conn-results-euw1.md
    │   ├── conn-results-euw2.md   ← from specs/conn-results-euw2.md
    │   ├── conn-results-use1.md   ← from specs/conn-results-use1.md
    │   └── conn-results-usw2.md   ← from specs/conn-results-usw2.md
    └── tools/
        ├── README.md              ← new index
        ├── checkov.md             ← from docs/tools/checkov.md
        ├── infracost.md           ← from docs/tools/infracost.md
        ├── prek.md                ← from docs/tools/prek.md
        ├── terraform-docs.md      ← from docs/tools/terraform-docs.md
        ├── tflint.md              ← from docs/tools/tflint.md
        └── uv.md                  ← from docs/tools/uv.md
```

---

## File Mapping

### Moves (git mv)

| Source | Destination |
|--------|-------------|
| `specs/DESIGN.md` | `docs/design/network-design.md` |
| `specs/TERRAFORM.md` | `docs/design/terraform-standards.md` |
| `docs/tagging-strategy.md` | `docs/design/tagging-strategy.md` |
| `docs/ipv6-assignment.md` | `docs/design/ipv6-assignment.md` |
| `docs/tgw-vpc-peering-attachments.md` | `docs/design/tgw-vpc-attachments.md` |
| `docs/getting-started.md` | `docs/dev/getting-started.md` |
| `docs/deployment.md` | `docs/dev/deployment.md` |
| `docs/key-pairs.md` | `docs/dev/key-pairs.md` |
| `docs/ngw-timeout.md` | `docs/dev/ngw-timeout.md` |
| `docs/tools/checkov.md` | `docs/dev/tools/checkov.md` |
| `docs/tools/infracost.md` | `docs/dev/tools/infracost.md` |
| `docs/tools/prek.md` | `docs/dev/tools/prek.md` |
| `docs/tools/terraform-docs.md` | `docs/dev/tools/terraform-docs.md` |
| `docs/tools/tflint.md` | `docs/dev/tools/tflint.md` |
| `docs/tools/uv.md` | `docs/dev/tools/uv.md` |
| `specs/conn-results-summary.md` | `docs/dev/connectivity/conn-results-summary.md` |
| `specs/conn-results-euw1.md` | `docs/dev/connectivity/conn-results-euw1.md` |
| `specs/conn-results-euw2.md` | `docs/dev/connectivity/conn-results-euw2.md` |
| `specs/conn-results-use1.md` | `docs/dev/connectivity/conn-results-use1.md` |
| `specs/conn-results-usw2.md` | `docs/dev/connectivity/conn-results-usw2.md` |

### Merges

- `docs/build.md` → append Quick Reference section into `docs/dev/deployment.md`, then delete `build.md`
- `specs/30-others.md` → append Terraform patterns/examples into `docs/design/terraform-standards.md`, then delete `30-others.md`

### Deletes

- `docs/build.md` (after merge)
- `specs/30-others.md` (after merge)
- `specs/conn-tests.md` (raw scratch notes, superseded by structured conn-results files)
- `specs/15-trivy-plan.md` (Trivy was deliberately removed, commit `5eb5e2d`)

### Stubs in specs/

Replace `specs/DESIGN.md` and `specs/TERRAFORM.md` with one-line redirect stubs:
> This document has moved to `docs/design/network-design.md` (or `terraform-standards.md`).

### Unchanged

- `specs/index.md` — update internal links to conn-results after move
- `specs/01-*` through `specs/16-*` historical feature plans (except 15) — stay in specs/
- All `modules/*/README.md`, `envs/*/README.md`, `bootstrap/README.md`, `scripts/README.md`, `vars/README.md` — terraform-docs generated, stay in place

---

## Root README.md Outline

Rewrite with these sections:
1. **Project summary** (2–3 sentences)
2. **Architecture diagram** (existing)
3. **Quick Start** → links to `docs/dev/getting-started.md` and `docs/dev/deployment.md`
4. **Repository Structure** (annotated tree)
5. **Documentation**
   - *Design*: links to all `docs/design/*`
   - *Operations & Tools*: links to all `docs/dev/*` and `docs/dev/tools/*`
6. **CI/CD Pipeline** (brief description)
7. **Modules** (table with links to module READMEs)
8. **Planning History** → `specs/index.md`

---

## New Files to Create

- `docs/dev/connectivity/README.md` — brief intro + links to per-region result files
- `docs/dev/tools/README.md` — table of tools with purpose and config file location

---

## Post-Move Fixes

- `docs/design/tgw-vpc-attachments.md` — update internal links (currently relative to `docs/`, will break after move)
- `specs/index.md` — update conn-results links to new `docs/dev/connectivity/` paths

---

## Verification

1. All links in root `README.md` resolve (`grep -r "\]\(" docs/ README.md` + spot check)
2. `docs/design/tgw-vpc-attachments.md` internal links work from new location
3. `specs/DESIGN.md` and `specs/TERRAFORM.md` stubs display redirect message
4. Deleted files are gone
5. `git log --follow docs/dev/deployment.md` confirms history preserved via `git mv`
