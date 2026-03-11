# Specs Index

| Spec | Title | Status |
|------|-------|--------|
| [01-build_script.MD](./01-build_script.MD) | Build Script: Parallel Deployment of VPCs, TGW, and TGW-VPC Attachments | Complete — `scripts/deploy.sh` and `scripts/destroy.sh` with Phase 0 (keypairs), Phase 1-3 |
| [02-dynamic-tgw-vpc-attachments.MD](./02-dynamic-tgw-vpc-attachments.MD) | Dynamic TGW-VPC Attachments and Remote State Refactoring | Complete — applied to AWS; includes VPC-side TGW routes (10.0.0.0/8) and security group/NACL updates for inter-VPC traffic |
| [03-create-cell1001.MD](./03-create-cell1001.MD) | Create dev/euw2/cell1001 (10.1.16.0/20) and register in TGW attachments | Complete — cell1001 deployed to AWS; inter-VPC routing between cell1000 and cell1001 via TGW is working |
| [04-deploy-cell000-cell0001.MD](./04-deploy-cell000-cell0001.MD) | Deploy prod/euw2/cell0000 and prod/euw2/cell0001 | Complete — both cells deployed to AWS; TGW attachments + `10.0.0.0/8 → TGW` routes applied to prod |
| [05-deploy-keypairs-euw2.MD](./05-deploy-keypairs-euw2.MD) | Create SSH Keypairs for dev/euw2 and prod/euw2, fix backend state issues | Complete — keypairs deployed; inline keypair creation removed from cells; deploy/destroy scripts updated with Phase 0/4 for keypairs |
| [06-deploy-region-eu-west-1.MD](./06-deploy-region-eu-west-1.MD) | Deploy Region eu-west-1 and test inter-region connectivity | Complete — euw1 TGW (ASN 64515), dev cells (cell3000/3001), prod cells (cell2000/2001), TGW-VPC attachments, and TGW peering (euw2↔euw1) fully deployed and verified |
| [07-bash-to-python.MD](./07-bash-to-python.MD) | Move deploy/destroy scripts from Bash to Python | Complete — `scripts/deploy.py` and `scripts/destroy.py` implemented with Typer CLI, Pydantic config, rich output, TGW peering readiness gate, parallel phase execution via `ThreadPoolExecutor`, and full unit test suite |
| [08-deploy-usw2-usw1-plan.md](./08-deploy-usw2-usw1-plan.md) | Deploy Regions us-west-2 and us-east-1 | Complete — 4 regions (euw2, euw1, usw2, use1) fully deployed; full-mesh TGW peering (6 attachments); `--parallelism` flag added to deploy/destroy scripts |
| [09-connectivity-test-plan.md](./09-connectivity-test-plan.md) | Ping connectivity tests across all 4 regions (prod + dev) | Complete — 32/32 PASS, 0% packet loss; results in [conn-results-summary.md](../docs/dev/connectivity/conn-results-summary.md) |
| [10-fix-infracost-plan.md](./10-fix-infracost-plan.md) | Fix Infracost integration | Complete |
| [12-tfdocs-pipeline-plan.md](./12-tfdocs-pipeline-plan.md) | Add terraform-docs to the CI/CD pipeline | Complete |
| [13-tflint-pipeline-plan.md](./13-tflint-pipeline-plan.md) | Add tflint to the CI/CD pipeline | Complete |
| [14-checkov-plan.md](./14-checkov-plan.md) | Add Checkov static security analysis to the CI/CD pipeline | Complete |
| [15-trivy-plan.md](./15-trivy-plan.md) | Add Trivy IaC misconfiguration scanning to the CI/CD pipeline | Complete |
| [16-uv-python-plan.md](./16-uv-python-plan.md) | Standardise Python dependency management on uv with a virtualenv | Complete |
| [17-docs.md](./17-docs.md) | Docs reorganisation — consolidate docs/ and specs/ into structured docs/design/ and docs/dev/ hierarchy | Complete |

## Notes

- Use the DESIGN.md doc in this folder to create any new features
- Use the index.md file to keep track of all features
