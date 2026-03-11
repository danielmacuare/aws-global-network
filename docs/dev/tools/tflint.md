# tflint

[tflint](https://github.com/terraform-linters/tflint) is a Terraform linter that catches errors and bad practices that `terraform validate` misses.

## What tflint catches

| Category | Examples |
|----------|---------|
| Type errors and invalid values | Passing a string where a number is expected; referencing a variable that does not exist |
| Deprecated syntax | Resource arguments that have been removed or renamed in newer provider versions |
| AWS-specific rules | Invalid instance types, unsupported region strings, deprecated argument names (via the `tflint-ruleset-aws` plugin) |
| Best practices | Naming conventions, unused declarations |

## Configuration

The tflint config lives at [`tools/.tflint.hcl`](../../tools/.tflint.hcl). Key settings:

- `call_module_type = "none"` — tflint does not resolve module sources. This avoids requiring `terraform init` before linting and makes the lint job self-contained in CI.
- `deep_check = false` — disables live AWS API calls (e.g. verifying that an AMI ID exists in the account). Static analysis still catches the most actionable errors without needing AWS credentials.
- AWS ruleset plugin pinned to version `0.45.0`.

## Running tflint locally

### Via prek (pre-commit hook)

tflint runs automatically on every commit via the `terraform_tflint` hook configured in [`tools/prek.yaml`](../../tools/prek.yaml).

To run the hook manually against all files:

```bash
prek -c tools/prek.yaml run --all-files terraform_tflint
```

To run against staged files only (same as what happens on commit):

```bash
prek -c tools/prek.yaml run terraform_tflint
```

### Directly against a single directory

```bash
tflint --config="$(git rev-parse --show-toplevel)/tools/.tflint.hcl" --chdir=modules/create-vpc
```

### Directly against all Terraform directories

```bash
while IFS= read -r dir; do
  echo "==> Linting: $dir"
  tflint --config="$(git rev-parse --show-toplevel)/tools/.tflint.hcl" --chdir="$dir"
done < <(find bootstrap envs modules vars -name '*.tf' -not -path '*/.terraform/*' -printf '%h\n' | sort -u)
```

## CI job

The `tflint` job in [`.github/workflows/pipeline.yml`](../../.github/workflows/pipeline.yml) runs on every pull request. It:

1. Checks out the PR branch.
2. Installs tflint `v0.61.0` via the official `terraform-linters/setup-tflint@v4` action.
3. Runs `tflint --init` to download the AWS ruleset plugin declared in `tools/.tflint.hcl`.
4. Discovers every directory under `modules/` and `envs/` that contains `.tf` files (excluding `.terraform/` subdirectories) and lints each one.
5. Accumulates failures across all directories before exiting — all lint errors are reported in a single run rather than stopping at the first failing directory.

The job fails if any lint error is found in any directory. It does not run on pushes to `main`.

## Updating the AWS ruleset plugin version

1. Check the [tflint-ruleset-aws releases](https://github.com/terraform-linters/tflint-ruleset-aws/releases) for the latest version.
2. Update the `version` field in `tools/.tflint.hcl`.
3. Update `tflint_version` in the CI job in `.github/workflows/pipeline.yml` if a newer tflint version is needed for compatibility.
4. Run `tflint --init --config=tools/.tflint.hcl` locally to download the new plugin version.
5. Run `prek -c tools/prek.yaml run --all-files terraform_tflint` to verify the codebase is clean.
