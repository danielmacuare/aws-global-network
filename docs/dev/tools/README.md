# CI/CD and Development Tools

| Tool | Purpose | Config |
|------|---------|--------|
| [Checkov](checkov.md) | Static security scanning | `tools/.checkov.yaml` |
| [Infracost](infracost.md) | Cost estimation on PRs | `tools/infracost.yml` |
| [Prek](prek.md) | Pre-commit hook runner | `tools/prek.yaml` |
| [terraform-docs](terraform-docs.md) | Auto-generate module READMEs | `tools/.terraform-docs.yml` |
| [tf-validate](tf-validate.md) | Parallel Terraform validate with timing | `scripts/tf_validate.py` |
| [tflint](tflint.md) | Terraform linter | `tools/.tflint.hcl` |
| [uv](uv.md) | Python dependency management | `pyproject.toml` / `uv.lock` |

## Pinned Tool Versions

| Tool | Pinned version | Source of truth |
|------|---------------|-----------------|
| Terraform | `1.14.4` | `.terraform-version` |
| TFLint | `v0.61.0` | `.github/workflows/pipeline.yml` |
| TFLint AWS ruleset | `0.45.0` | `tools/.tflint.hcl` |
| Checkov | `3.2.434` | `pyproject.toml` + `tools/prek.yaml` |
| Infracost | `v0.10.43` | `.github/workflows/pipeline.yml` |
| terraform-docs | `v0.21.0` | `.github/workflows/pipeline.yml` |
| pre-commit-terraform | `v1.105.0` | `tools/prek.yaml` |
| Python | `3.11` | `.python-version` |
