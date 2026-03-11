# Connectivity Test Results — us-west-2 (usw2)

**Test date:** 2026-02-27
**Method:** SSH ProxyCommand via bastion, `ping -c 4`

## PROD — Source: private-usw2-prod-priv-0-cell4000 (10.32.0.203)

Bastion: `34.222.115.125` | Key: `usw2-prod.pem`

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|-------------|--------------|--------|
| euw2-prod cell0000 | 10.0.0.31 | inter-region | 0% | 126.94 | PASS |
| euw1-prod cell2000 | 10.16.0.24 | inter-region | 0% | 118.31 | PASS |
| use1-prod cell6000 | 10.48.0.248 | inter-region | 0% | 56.28 | PASS |
| usw2-prod cell4001 | 10.32.16.31 | intra-region | 0% | 1.46 | PASS |

## DEV — Source: private-usw2-dev-priv-0-cell5000 (10.33.0.194)

Bastion: `35.90.26.6` | Key: `usw2-dev.pem`

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|-------------|--------------|--------|
| euw2-dev cell1000 | 10.1.0.148 | inter-region | 0% | 129.25 | PASS |
| euw1-dev cell3000 | 10.17.0.7 | inter-region | 0% | 119.22 | PASS |
| use1-dev cell7000 | 10.49.0.187 | inter-region | 0% | 56.97 | PASS |
| usw2-dev cell5001 | 10.33.16.146 | intra-region | 0% | 1.22 | PASS |
