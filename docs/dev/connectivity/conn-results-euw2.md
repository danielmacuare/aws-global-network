# Connectivity Test Results — eu-west-2 (euw2)

**Date:** 2026-02-27
**Tested by:** Claude Code (automated SSH + ping via ProxyCommand)

## PROD — Source: private-euw2-prod-priv-0-cell0000 (10.0.0.31)

Bastion: `18.171.186.152` | Key: `ssh-keys/euw2-prod.pem`

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|-------------|--------------|--------|
| euw1-prod cell2000 | 10.16.0.24 | inter-region | 0% | 12.58 | PASS |
| usw2-prod cell4000 | 10.32.0.203 | inter-region | 0% | 131.30 | PASS |
| use1-prod cell6000 | 10.48.0.248 | inter-region | 0% | 76.37 | PASS |
| euw2-prod cell0001 | 10.0.16.86 | intra-region | 0% | 1.14 | PASS |

## DEV — Source: private-euw2-dev-priv-0-cell1000 (10.1.0.148)

Bastion: `35.178.244.94` | Key: `ssh-keys/euw2-dev.pem`

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|-------------|--------------|--------|
| euw1-dev cell3000 | 10.17.0.7 | inter-region | 0% | 13.28 | PASS |
| usw2-dev cell5000 | 10.33.0.194 | inter-region | 0% | 131.96 | PASS |
| use1-dev cell7000 | 10.49.0.187 | inter-region | 0% | 77.83 | PASS |
| euw2-dev cell1001 | 10.1.16.115 | intra-region | 0% | 0.97 | PASS |

## Summary

All 8 connectivity tests **PASSED** with 0% packet loss.

### RTT observations

- **Intra-region (euw2 -> euw2):** ~1–1.1 ms — consistent with same-region TGW routing
- **euw2 -> euw1 (London -> Ireland):** ~12.6–13.3 ms — short cross-region hop
- **euw2 -> use1 (London -> N. Virginia):** ~76–78 ms — transatlantic
- **euw2 -> usw2 (London -> Oregon):** ~131–132 ms — longest path, expected for London-to-US-West
