# Prek — Pre-commit Hooks

[Prek](https://github.com/j178/prek) is a Rust-based replacement for the `pre-commit` framework. It is fully compatible with the `pre-commit` hook ecosystem and configuration format, but is faster and ships as a single binary.

## Installation

```bash
brew install j178/tap/prek
```

## Configuration

The hook configuration lives in [`tools/prek.yaml`](../../tools/prek.yaml). It uses the same format as `.pre-commit-config.yaml`.

The git hook is installed to `.git/hooks/pre-commit` and is wired to read from that path automatically:

```sh
prek -c tools/prek.yaml install
```

To overwrite an existing hook:

```sh
prek -c tools/prek.yaml install --overwrite
```

## Configured Hooks

All hooks are sourced from [`antonbabenko/pre-commit-terraform`](https://github.com/antonbabenko/pre-commit-terraform) v1.105.0, except Checkov which comes from its own repo.

### terraform validate (`terraform_validate`)

Runs `terraform validate` with `-backend=false` across all directories under `bootstrap/`, `envs/`, and `modules/`. Catches syntax errors and invalid references without connecting to the S3 backend.

### tflint (`terraform_tflint`)

Runs [TFLint](https://github.com/terraform-linters/tflint) against all `.tf` files. Uses the config at `tools/.tflint.hcl` (AWS ruleset, no deep check). Catches misconfigurations, deprecated syntax, and AWS-specific errors that `terraform validate` does not.

### terraform-docs (`terraform_docs`)

Regenerates `README.md` for every module under `modules/` by injecting auto-generated inputs/outputs/requirements between the `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->` sentinel comments. If the README changes, prek stages the updated file and the commit proceeds.

### checkov (`checkov`)

Runs [Checkov](https://www.checkov.io/) static security analysis using the config at `tools/.checkov.yaml`. Hard-fails on HIGH/CRITICAL findings; soft-fails on LOW/MEDIUM.

## Running Hooks Manually

Run against all files in the repo:

```bash
prek -c tools/prek.yaml run --all-files
```

Run against staged files only (same as what happens on commit):

```bash
prek -c tools/prek.yaml run
```

Run a specific hook:

```bash
prek -c tools/prek.yaml run terraform_tflint
```

Run against the last commit:

```bash
prek -c tools/prek.yaml --last-commit
```

## Adding New Tools

To add a new hook:

1. Find the hook id in the relevant repository's `.pre-commit-hooks.yaml`.
2. Add it to `tools/prek.yaml` under the appropriate `repo` block (or add a new `repo` entry).
3. Run `prek -c tools/prek.yaml install-hooks` to pre-fetch environments.
4. Add a section to this document describing what the hook does.

## Skipping Hooks

To skip a specific hook for a single commit (comma-separate multiple hook IDs):

```bash
SKIP=terraform_tflint git commit -m "..."
SKIP=terraform_validate,checkov git commit -m "..."
```

To skip prek entirely:

```bash
git commit --no-verify -m "..."
```

> Use `--no-verify` sparingly. It bypasses all git hooks, not just prek.

## Updating Hook Versions

```bash
prek -c tools/prek.yaml auto-update
```

This updates the `rev` field in `tools/prek.yaml` to the latest tag for each repository.
