# Specs Index

| Spec | Title | Status |
|------|-------|--------|
| [01-build_script.MD](./01-build_script.MD) | Build Script: Parallel Deployment of VPCs, TGW, and TGW-VPC Attachments | `scripts/deploy.sh` complete; `scripts/destroy.sh` complete |
| [02-dynamic-tgw-vpc-attachments.MD](./02-dynamic-tgw-vpc-attachments.MD) | Dynamic TGW-VPC Attachments and Remote State Refactoring | Complete — applied to AWS; includes VPC-side TGW routes (10.0.0.0/8) and security group/NACL updates for inter-VPC traffic |
| [03-create-cell1001.MD](./03-create-cell1001.MD) | Create dev/euw2/cell1001 (10.1.16.0/20) and register in TGW attachments | Complete — cell1001 deployed to AWS; inter-VPC routing between cell1000 and cell1001 via TGW is working |
