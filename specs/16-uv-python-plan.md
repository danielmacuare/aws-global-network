# Feature 16 — Standardise Python Dependency Management on uv

## Goal

Replace all ad-hoc `pip install` calls (current and planned) with a single `uv`-managed virtualenv at the repo root so that every Python tool — starting with Checkov — is installed reproducibly from a committed `uv.lock` file. This supersedes the `pip install checkov==3.2.434` approach described in [feature 14](./14-checkov-plan.md) and establishes the pattern for any future Python tools.

---

## Background

The repo already has partial uv adoption: `scripts/pyproject.toml` and `scripts/.python-version` manage the deploy/destroy Python scripts. That is a separate, self-contained package. This feature adds a second, distinct `pyproject.toml` at the **repo root** whose sole purpose is managing CI/dev tooling (Checkov, and any future Python-based scanners or formatters). The two `pyproject.toml` files remain independent — `scripts/` manages application code; the root manages tooling.

The feature 14 checkov plan specifies `pip install checkov==3.2.434` in the CI job. That approach works but has two drawbacks: (1) pip has no lockfile, so transitive dependencies can drift between runs; (2) every new Python tool needs its own install step. `uv` solves both: it resolves and locks the full dependency graph into `uv.lock`, and a single `uv sync` installs everything.

---

## Why uv Over Alternatives

| Tool | Reason not chosen |
|------|-------------------|
| plain pip | No lockfile; non-deterministic transitive dependencies |
| pip-tools | Two-file workflow (`.in` + `.txt`); slower; no venv management |
| Poetry | Heavy; `poetry.lock` format is non-standard; slower CI startup |
| Pipenv | Largely superseded; slow resolver |
| **uv** | Single binary; combines venv creation, dependency resolution, lockfile, and install; written in Rust so it is 10-100x faster than pip; PEP 517/518/723 compatible; `astral-sh/setup-uv` official GitHub Action available |

---

## Solution Overview

1. Add a `pyproject.toml` at the repo root declaring `checkov` as a dev dependency.
2. Commit the generated `uv.lock` for reproducible installs.
3. Pin a `.python-version` file at the repo root so uv and CI agree on the interpreter.
4. Replace the planned `pip install checkov==3.2.434` CI step with `astral-sh/setup-uv` + `uv sync`.
5. Invoke checkov via `uv run checkov` in the CI job so it always uses the managed venv.
6. Document the workflow in `docs/tools/uv.md`.

---

## Implementation Plan

### Step 1 — Create `.python-version` at the repo root

Create `.python-version` at the repo root pinning Python 3.11 (matching `scripts/.python-version`):

```
3.11
```

uv reads this file automatically when creating or selecting an interpreter for the root virtualenv. CI will also use it via `astral-sh/setup-uv` with `python-version-file: .python-version`.

### Step 2 — Create `pyproject.toml` at the repo root

Create `/pyproject.toml` (distinct from `scripts/pyproject.toml`):

```toml
[project]
name = "aws-global-network-tools"
version = "0.1.0"
requires-python = ">=3.11"
# No runtime dependencies — this package exists only to manage dev tooling.
dependencies = []

[dependency-groups]
dev = [
    "checkov==3.2.434",
]
```

Key decisions:
- `[dependency-groups]` (PEP 735, supported by uv) rather than `[project.optional-dependencies]` — dependency groups are explicitly for non-publishable dev tooling. The package is not published to PyPI, so optional-dependencies would be misleading.
- `checkov==3.2.434` is pinned with `==` (exact) rather than `>=`. Checkov releases frequently and has historically introduced regressions. An exact pin in `pyproject.toml`, backed by `uv.lock`, gives two layers of reproducibility.
- `dependencies = []` — the root package is not an application; it has no runtime deps. All tooling lives under `[dependency-groups]`.
- The package name `aws-global-network-tools` distinguishes it from the scripts package (`aws-global-network-scripts`) if both are ever visible in the same environment.

### Step 3 — Generate and commit `uv.lock`

After creating `pyproject.toml` and `.python-version`, run locally:

```bash
uv lock
```

This resolves the full dependency graph for `checkov==3.2.434` and all its transitive dependencies and writes `uv.lock`. Commit the lockfile:

```bash
git add .python-version pyproject.toml uv.lock
git commit -m "feat: Add root pyproject.toml and uv.lock for Python tooling"
```

The lockfile is committed so CI gets a byte-for-byte reproducible install without a network round-trip to PyPI for resolution. `uv sync` in CI will install exactly what the lockfile specifies.

To verify the virtualenv works locally after locking:

```bash
uv sync --group dev
uv run checkov --version
```

### Step 4 — Update the checkov CI job in `pipeline.yml`

The feature 14 plan specifies this CI step:

```yaml
- name: Install Checkov
  run: pip install checkov==3.2.434
```

Replace it — and the setup — with:

```yaml
checkov:
  name: Checkov
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'

  steps:
    - name: Checkout PR branch
      uses: actions/checkout@v4
      with:
        ref: ${{ github.event.pull_request.head.ref }}

    - name: Install uv
      uses: astral-sh/setup-uv@v5
      with:
        python-version-file: .python-version
        enable-cache: true

    - name: Install Python dependencies
      run: uv sync --group dev

    - name: Run Checkov
      run: |
        uv run checkov \
          --config-file tools/.checkov.yaml \
          --directory . \
          --soft-fail-on LOW,MEDIUM \
          --hard-fail-on HIGH,CRITICAL
```

Notes:
- `astral-sh/setup-uv@v5` is the official action maintained by Astral (the uv authors). Pin to `v5` (the current major) rather than a specific SHA — Astral follows semver and does not make breaking changes within a major.
- `python-version-file: .python-version` — instructs the action to install the interpreter version declared in the file rather than duplicating the version in the workflow YAML.
- `enable-cache: true` — caches the uv download cache keyed on `uv.lock`. Subsequent runs skip network I/O for packages already downloaded, reducing install time from ~30s to ~3s.
- `uv sync --group dev` — installs only the `dev` dependency group (checkov and its transitive deps). Does not install the root package itself (no `--no-install-project` needed since `dependencies = []`).
- `uv run checkov` — runs checkov inside the managed `.venv` without requiring the developer or CI to activate it manually.
- All other checkov flags (`--config-file`, `--directory`, `--soft-fail-on`, `--hard-fail-on`) are unchanged from the feature 14 plan.

### Step 5 — prek / local developer workflow

No changes are needed to `tools/prek.yaml`. The `bridgecrewio/checkov` pre-commit hook (added in feature 14) installs its own isolated Python environment via pre-commit's hook isolation mechanism — it does not use the repo's virtualenv. The two are intentionally separate: the hook is for fast staged-file checks; the CI job is for full-repo analysis.

What developers do need to do after cloning the repo (add this to onboarding docs / README):

```bash
# Install uv (once, globally)
curl -LsSf https://astral.sh/uv/install.sh | sh

# From repo root — install tooling virtualenv
uv sync --group dev

# Verify
uv run checkov --version
```

The `.venv` directory created by `uv sync` at the repo root should be added to `.gitignore` if not already present:

```
/.venv
```

Developers do not need to activate the venv manually. `uv run <tool>` always resolves to the correct venv for the current directory.

### Step 6 — Create `docs/tools/uv.md`

Create a reference document at `docs/tools/uv.md` following the same structure as `docs/tools/tflint.md`.

Content to cover:

**What uv is** — a fast Python package and project manager written in Rust by Astral. It replaces pip, pip-tools, virtualenv, and pyenv for the purposes of this repo's tooling.

**Installation** — the one-liner for macOS/Linux and the note that uv is also available via Homebrew (`brew install uv`).

**Repository structure** — explain that the repo has two separate Python projects:
- `scripts/` — the deploy/destroy application (Typer CLI); managed independently with its own `pyproject.toml` and `.python-version`.
- repo root — Python dev tooling (Checkov, etc.); managed by the root `pyproject.toml` and `uv.lock`.

**Adding a new Python tool** — step-by-step:
1. Add the tool (pinned with `==`) to the `dev` group in the root `pyproject.toml`.
2. Run `uv lock` to regenerate the lockfile.
3. Run `uv sync --group dev` to install it.
4. Add the tool's invocation to the CI job in `pipeline.yml` using `uv run <tool>`.
5. Commit `pyproject.toml` and `uv.lock` together.

**Updating a pinned version**:
1. Change the version in `pyproject.toml`.
2. Run `uv lock` — uv re-resolves only what changed.
3. Commit both files.

**How the CI job uses uv** — describe the `astral-sh/setup-uv@v5` action, `uv sync`, and `uv run`; note that `enable-cache: true` makes subsequent runs fast via the GitHub Actions cache keyed on `uv.lock`.

**Running tools locally** — `uv run checkov --version`, `uv run checkov --directory . --config-file tools/.checkov.yaml`.

### Step 7 — Update `specs/index.md`

Add feature 16 with status "In planning".

Also add an amendment note to `specs/14-checkov-plan.md` pointing readers to this plan for the installation approach.

---

## Amendment to Feature 14

Feature 14 (checkov plan) Step 3 specifies `pip install checkov==3.2.434` in the CI job. **This plan supersedes that step.** When implementing feature 14, use the `uv`-based installation described in Step 4 of this plan instead. All other aspects of feature 14 (the config file, the prek hook, the checkov flags, the docs) remain unchanged.

---

## Files to Create / Modify

| File | Action | Description |
|------|--------|-------------|
| `.python-version` | **Create** | Pin Python 3.11 at repo root for uv and CI |
| `pyproject.toml` | **Create** | Root-level project metadata and `[dependency-groups] dev` containing checkov |
| `uv.lock` | **Create** (generated) | Full resolved dependency lockfile; committed for reproducibility |
| `.gitignore` | **Edit** | Add `/.venv` if not already present |
| `.github/workflows/pipeline.yml` | **Edit** | Replace planned `pip install checkov` step with `astral-sh/setup-uv@v5` + `uv sync` + `uv run checkov` |
| `docs/tools/uv.md` | **Create** | Reference doc: what uv is, install, add deps, update lockfile, CI usage |
| `specs/index.md` | **Edit** | Add feature 16 row |
| `specs/14-checkov-plan.md` | **Edit** | Add amendment note at top pointing to this plan for the install approach |

---

## Key Decisions

- **Root `pyproject.toml` is separate from `scripts/pyproject.toml`** — the scripts package is an application with runtime deps (Typer, Pydantic, rich). The root package is a tooling manifest with no runtime deps. Merging them would muddy the separation of concerns and complicate `uv run` invocations inside `scripts/`.
- **`[dependency-groups]` not `[project.optional-dependencies]`** — PEP 735 dependency groups are the idiomatic uv pattern for non-publishable dev tooling. Optional dependencies are intended for published packages where users might install extras. This package is never published.
- **Exact pin (`==`) in `pyproject.toml` plus `uv.lock`** — two layers of reproducibility. The `==` pin in `pyproject.toml` makes the intent explicit and human-readable. The lockfile pins transitive dependencies. If the lockfile is ever regenerated from scratch, the direct dependency version cannot drift.
- **`uv.lock` committed** — the lockfile is the guarantee of reproducibility. Without it, `uv sync` would re-resolve transitive dependencies on every CI run, which could introduce silent breakage when upstream packages release new versions. Committing the lockfile makes every install identical until a developer explicitly runs `uv lock` to update it.
- **`.python-version` at repo root** — avoids duplicating the Python version string in `pyproject.toml` (`requires-python`), the GitHub Actions workflow, and any local tooling. `astral-sh/setup-uv` reads it automatically. The `requires-python = ">=3.11"` in `pyproject.toml` remains as a compatibility floor, not an exact pin.
- **`astral-sh/setup-uv@v5` pinned to major** — Astral maintains semver guarantees within a major version. Pinning to `@v5` rather than a specific SHA balances stability with receiving patch fixes automatically. This is consistent with how other actions in the pipeline are pinned (e.g. `actions/checkout@v4`).
- **`enable-cache: true`** — the uv download cache is keyed on the hash of `uv.lock`. When the lockfile has not changed (the common case), the cache hit means `uv sync` completes in ~2-3 seconds rather than ~25-30 seconds. Cache misses happen only when `uv.lock` changes, which is intentional.
- **prek hook unchanged** — the `bridgecrewio/checkov` pre-commit hook manages its own isolated environment via pre-commit's hook isolation mechanism. Integrating it with the repo venv would require using `language: system` or `language: python` with a `additional_dependencies` list, which adds complexity. The current isolation is a feature, not a limitation: the hook always uses the exact checkov version pinned in `prek.yaml` regardless of what is in the repo venv.
- **No `actions/setup-python` step** — `astral-sh/setup-uv` with `python-version-file` handles Python installation. Adding a separate `actions/setup-python` step would be redundant and could cause version conflicts.

---

## Acceptance Criteria

- [ ] `.python-version` exists at repo root containing `3.11`
- [ ] `pyproject.toml` exists at repo root with `[dependency-groups] dev` containing `checkov==3.2.434`
- [ ] `uv.lock` exists at repo root and is committed
- [ ] `uv sync --group dev` runs cleanly from the repo root and installs checkov
- [ ] `uv run checkov --version` prints `3.2.434`
- [ ] The `checkov` CI job in `pipeline.yml` uses `astral-sh/setup-uv@v5` and `uv run checkov` (no `pip install` step)
- [ ] The CI job passes on a PR with no HIGH/CRITICAL findings
- [ ] The CI job fails on a PR that introduces a HIGH/CRITICAL finding
- [ ] `docs/tools/uv.md` exists and documents installation, adding dependencies, updating the lockfile, and CI usage
- [ ] `specs/14-checkov-plan.md` contains an amendment note directing readers to this plan for the install approach
- [ ] `specs/index.md` lists feature 16
- [ ] `.gitignore` includes `/.venv`
