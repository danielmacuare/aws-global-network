# Connectivity Test Results — eu-west-1 (euw1)

**Date:** 2026-02-27
**Tested from:** euw1 (eu-west-1, Ireland)

## PROD — Source: private-euw1-prod-priv-0-cell2000 (10.16.0.24)

Bastion: `18.202.240.108` | Key: `euw1-prod.pem`

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|-------------|--------------|--------|
| euw2-prod cell0000 | 10.0.0.31 | inter-region | 0% | 12.85 | PASS |
| usw2-prod cell4000 | 10.32.0.203 | inter-region | 0% | 117.98 | PASS |
| use1-prod cell6000 | 10.48.0.248 | inter-region | 0% | 69.20 | PASS |
| euw1-prod cell2001 | 10.16.16.114 | intra-region | 0% | 0.97 | PASS |

## DEV — Source: private-euw1-dev-priv-0-cell3000 (10.17.0.7)

Bastion: `46.137.38.4` | Key: `euw1-dev.pem`

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|-------------|--------------|--------|
| euw2-dev cell1000 | 10.1.0.148 | inter-region | 0% | 11.62 | PASS |
| usw2-dev cell5000 | 10.33.0.194 | inter-region | 0% | 118.54 | PASS |
| use1-dev cell7000 | 10.49.0.187 | inter-region | 0% | 70.46 | PASS |
| euw1-dev cell3001 | 10.17.16.188 | intra-region | 0% | 1.19 | PASS |
