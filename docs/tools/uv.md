# uv

[uv](https://github.com/astral-sh/uv) is a single binary that replaces `pip`, `virtualenv`, and `pip-tools`. Written in Rust, it resolves and installs Python dependencies 10–100x faster than pip and produces a fully reproducible lockfile from a `pyproject.toml` declaration.

## Why uv

| Concern | pip + pip-tools | uv |
|---------|----------------|----|
| Speed | Slow resolver | 10–100x faster (written in Rust) |
| Lockfile | Separate `pip-compile` step | `uv lock` built-in |
| Virtual env management | Separate `virtualenv` / `venv` | `uv venv` built-in |
| Single binary | No | Yes — one install, no Python needed |
| Reproducibility | `requirements.txt` can drift | `uv.lock` is deterministic and committed |

## Installation

```bash
# macOS / Linux (recommended)
curl -LsSf https://astral.sh/uv/install.sh | sh

# macOS via Homebrew
brew install uv
```

After installation, verify with:

```bash
uv --version
```

## Repository structure

This repo has two separate Python contexts:

| Path | Purpose |
|------|---------|
| Repo root (`pyproject.toml`) | Tooling only — Checkov and other CI/dev tools |
| `scripts/` | Application scripts for deploying and destroying the network lab |

Each context has its own `pyproject.toml` (and, for the repo root, a committed `uv.lock`). They are managed independently.

## Developer setup after cloning

From the repo root, install the dev tools:

```bash
uv sync --group dev
```

This creates a `.venv/` at the repo root (gitignored) and installs all pinned dependencies from `uv.lock`. Verify the install:

```bash
uv run checkov --version
```

## Adding a new Python tool

1. Add the package (with a pinned version) to the `dev` dependency group in `pyproject.toml`:

   ```toml
   [dependency-groups]
   dev = [
       "checkov==3.2.434",
       "your-tool==1.2.3",
   ]
   ```

2. Regenerate the lockfile:

   ```bash
   uv lock
   ```

3. Sync the local environment:

   ```bash
   uv sync --group dev
   ```

4. Use `uv run <tool>` in CI (see below) and locally.

5. Commit both `pyproject.toml` and `uv.lock`.

## Updating a pinned version

1. Change the version in `pyproject.toml`.
2. Regenerate the lockfile:

   ```bash
   uv lock
   ```

3. Commit both files together so the lockfile always matches the declaration.

## How CI uses uv

The CI pipeline uses the official `astral-sh/setup-uv@v5` action to install uv, then syncs the dev group and runs tools via `uv run`:

```yaml
- name: Set up uv
  uses: astral-sh/setup-uv@v5
  with:
    python-version-file: .python-version
    enable-cache: true

- name: Install dev dependencies
  run: uv sync --group dev

- name: Run Checkov
  run: |
    uv run checkov \
      --config-file tools/.checkov.yaml \
      --directory . \
      --soft-fail-on LOW,MEDIUM \
      --hard-fail-on HIGH,CRITICAL
```

Key settings:

- `python-version-file: .python-version` — pins the Python version from the committed `.python-version` file (currently `3.11`).
- `enable-cache: true` — caches the uv download cache across CI runs, making dependency installs faster after the first run.
- `uv run <tool>` — runs the tool inside the managed virtual environment without requiring an explicit `source .venv/bin/activate`.
