# terraform-docs

[terraform-docs](https://terraform-docs.io) generates structured documentation from Terraform module source files — reading variable definitions, outputs, providers, and requirements — and injects the result into a module's `README.md`.

## What it does and why

Handwritten module documentation goes stale. terraform-docs solves this by deriving the documentation directly from the Terraform source: variable `description` fields, output `description` fields, required providers, and minimum Terraform versions are all parsed automatically.

Each module in this repo has a `README.md` that contains a sentinel comment block:

```
<!-- BEGIN_TF_DOCS -->
...generated content...
<!-- END_TF_DOCS -->
```

terraform-docs rewrites everything between those two comments. Content outside the sentinel block (overview, usage examples, architecture notes) is left untouched.

## Local workflow via prek

The `terraform_docs` hook is configured in [`tools/prek.yaml`](../../tools/prek.yaml). When you commit, prek runs terraform-docs automatically against any staged `.tf` files, updating the `README.md` in the affected module(s). If the README changes, prek stages the updated file and the commit proceeds normally.

To run terraform-docs manually against all modules at once:

```bash
prek -c tools/prek.yaml run --all-files terraform_docs
```

To run it against staged files only (same as the on-commit behaviour):

```bash
prek -c tools/prek.yaml run terraform_docs
```

## CI enforcement

The `terraform-docs` job in `.github/workflows/pipeline.yml` runs on every pull request. It uses the official [`terraform-docs/gh-actions`](https://github.com/terraform-docs/gh-actions) action to regenerate docs for all modules and compares the output to what is already committed.

The key setting is `fail-on-diff: true`. If the generated output differs from the committed `README.md` — meaning the docs are stale — the job fails and the PR is blocked until the author runs terraform-docs locally and pushes the updated README.

Modules checked by CI:

- `modules/create-ec2`
- `modules/create-key-pair`
- `modules/create-tgw`
- `modules/create-tgw-vpc-attachment`
- `modules/create-vpc`
- `modules/security`

## Sentinel comment format

Every module README must contain the sentinel comments for injection to work:

```markdown
<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
```

Place these comments in the README at the location where the generated table (inputs, outputs, providers, requirements) should appear. terraform-docs will fill in and maintain everything between them.
