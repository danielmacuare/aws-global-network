## TLDR

Adds automated inter-region connectivity smoke tests, a lock-file update script, and updates Terraform lock files with Linux hashes for CI. Includes parallel test execution, unit tests, documentation, and minor code cleanup across modules.

## Description

This branch introduces a `smoke_test.py` script that verifies cross-region network connectivity after deployments by SSH-proxying through each cell's bastion host and pinging private hosts in every other same-environment cell. Tests run in parallel across all cells. A companion `lock-files.py` script regenerates `.terraform.lock.hcl` files for all target platforms in parallel. Terraform lock files are updated with Linux hashes to unblock CI, and minor cleanup is applied to modules.

## Key Changes

- **scripts/smoke_test.py**: New script automating inter-region connectivity tests via ProxyJump SSH. Supports `--dry-run`, `--debug`, `--regions` filter, and configurable timeouts. Runs all cells in parallel.
- **scripts/tests/test_smoke_test.py**: Unit test suite (318 lines) covering the smoke test logic.
- **scripts/lock-files.py**: New script to regenerate `.terraform.lock.hcl` files across all Terraform directories for multiple platforms in parallel using `terraform providers lock`.
- **scripts/README.md**: New documentation covering both scripts' usage and options.
- **docs/dev/tools/smoke-test.md**: Developer documentation for the smoke test workflow.
- **Terraform lock files**: Updated `.terraform.lock.hcl` across all environments and modules to add Linux (`linux_amd64`, `linux_arm64`) hashes required by CI.
- **modules/create-vpc/providers.tf**: Removed commented-out dead code.
- **modules/security/security-groups.tf**: Fixed dash naming in security group resources.

## Verification

- Run unit tests: `python -m pytest scripts/tests/test_smoke_test.py`
- Dry-run smoke test: `python scripts/smoke_test.py --dry-run`
- Verify lock files regenerate: `python scripts/lock-files.py --help`
- Confirm CI pipelines pass with updated Linux hashes in lock files.

## Commit Merge Message

```
Merge [PR#?] - feat: Add smoke tests and lock-file update scripts

- From branch: feature/more-tweaks
- Resolves: PR#?
- Description:
  - Add smoke_test.py for automated inter-region connectivity verification via ProxyJump SSH with parallel execution
  - Add lock-files.py to regenerate Terraform lock files for all platforms in parallel
  - Update all .terraform.lock.hcl files with Linux hashes to unblock CI
  - Add unit tests, developer docs, and minor module cleanup
```
