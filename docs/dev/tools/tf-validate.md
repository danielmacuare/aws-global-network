# tf-validate

`scripts/tf_validate.py` runs `terraform validate` in parallel across every Terraform directory in the repo and prints a Rich table showing pass/fail status and how long each directory took.

## Usage

```bash
# Default parallelism (cpu count)
uv run --project scripts/ python scripts/tf_validate.py

# Custom parallelism
uv run --project scripts/ python scripts/tf_validate.py --parallelism 16

# Help
uv run --project scripts/ python scripts/tf_validate.py --help
```

## Output

```
────────────────────────── Terraform Validate ──────────────────────────────
Found 41 Terraform directories — running with 8 workers

validating ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 41/41 0:00:42

                        Validate Results
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━┓
┃ Directory                        ┃  Status  ┃ Duration ┃ Output ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━┩
│ bootstrap                        │   PASS   │       7s │        │
│ envs/dev/euw2/cell1000           │   PASS   │       9s │        │
│ ...                              │   ...    │      ... │        │
├──────────────────────────────────┼──────────┼──────────┼────────┤
│ Total: 41 dirs                   │ 41 passed│  42s wall│        │
└──────────────────────────────────┴──────────┴──────────┴────────┘
```

Failures are sorted to the top of the table. Full error output is printed below the table for any failing directory.

## Scope

Searches for `.tf` files under `bootstrap/`, `envs/`, and `modules/`, excluding `.terraform/` subdirectories. Assumes `terraform init` has already been run in each directory (providers must be present in `.terraform/providers/`).

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | All directories passed |
| `1` | One or more directories failed |
