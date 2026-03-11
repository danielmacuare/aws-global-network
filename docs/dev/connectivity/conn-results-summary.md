# Connectivity Test Results — Full Global Network

**Date:** 2026-02-27
**Total tests:** 32 (16 PROD + 16 DEV)
**Result:** 32/32 PASS — 0% packet loss on all paths

---

## RTT Matrix (avg ms)

### PROD

| Source → | euw2 cell0000 | euw1 cell2000 | usw2 cell4000 | use1 cell6000 | intra-region peer |
|----------|:---:|:---:|:---:|:---:|:---:|
| **euw2-prod** | — | 12.58 | 131.30 | 76.37 | 1.14 (cell0001) |
| **euw1-prod** | 12.85 | — | 117.98 | 69.20 | 0.97 (cell2001) |
| **usw2-prod** | 126.94 | 118.31 | — | 56.28 | 1.46 (cell4001) |
| **use1-prod** | 77.10 | 69.28 | 57.21 | — | 1.05 (cell6001) |

### DEV

| Source → | euw2 cell1000 | euw1 cell3000 | usw2 cell5000 | use1 cell7000 | intra-region peer |
|----------|:---:|:---:|:---:|:---:|:---:|
| **euw2-dev** | — | 13.28 | 131.96 | 77.83 | 0.97 (cell1001) |
| **euw1-dev** | 11.62 | — | 118.54 | 70.46 | 1.19 (cell3001) |
| **usw2-dev** | 129.25 | 119.22 | — | 56.97 | 1.22 (cell5001) |
| **use1-dev** | 76.27 | 67.91 | 56.48 | — | 1.35 (cell7001) |

---

## All Results

### eu-west-2 (London) — PROD source: 10.0.0.31

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|:-----------:|:------------:|:------:|
| euw1-prod cell2000 | 10.16.0.24 | inter-region | 0% | 12.58 | PASS |
| usw2-prod cell4000 | 10.32.0.203 | inter-region | 0% | 131.30 | PASS |
| use1-prod cell6000 | 10.48.0.248 | inter-region | 0% | 76.37 | PASS |
| euw2-prod cell0001 | 10.0.16.86 | intra-region | 0% | 1.14 | PASS |

### eu-west-2 (London) — DEV source: 10.1.0.148

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|:-----------:|:------------:|:------:|
| euw1-dev cell3000 | 10.17.0.7 | inter-region | 0% | 13.28 | PASS |
| usw2-dev cell5000 | 10.33.0.194 | inter-region | 0% | 131.96 | PASS |
| use1-dev cell7000 | 10.49.0.187 | inter-region | 0% | 77.83 | PASS |
| euw2-dev cell1001 | 10.1.16.115 | intra-region | 0% | 0.97 | PASS |

### eu-west-1 (Ireland) — PROD source: 10.16.0.24

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|:-----------:|:------------:|:------:|
| euw2-prod cell0000 | 10.0.0.31 | inter-region | 0% | 12.85 | PASS |
| usw2-prod cell4000 | 10.32.0.203 | inter-region | 0% | 117.98 | PASS |
| use1-prod cell6000 | 10.48.0.248 | inter-region | 0% | 69.20 | PASS |
| euw1-prod cell2001 | 10.16.16.114 | intra-region | 0% | 0.97 | PASS |

### eu-west-1 (Ireland) — DEV source: 10.17.0.7

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|:-----------:|:------------:|:------:|
| euw2-dev cell1000 | 10.1.0.148 | inter-region | 0% | 11.62 | PASS |
| usw2-dev cell5000 | 10.33.0.194 | inter-region | 0% | 118.54 | PASS |
| use1-dev cell7000 | 10.49.0.187 | inter-region | 0% | 70.46 | PASS |
| euw1-dev cell3001 | 10.17.16.188 | intra-region | 0% | 1.19 | PASS |

### us-west-2 (Oregon) — PROD source: 10.32.0.203

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|:-----------:|:------------:|:------:|
| euw2-prod cell0000 | 10.0.0.31 | inter-region | 0% | 126.94 | PASS |
| euw1-prod cell2000 | 10.16.0.24 | inter-region | 0% | 118.31 | PASS |
| use1-prod cell6000 | 10.48.0.248 | inter-region | 0% | 56.28 | PASS |
| usw2-prod cell4001 | 10.32.16.31 | intra-region | 0% | 1.46 | PASS |

### us-west-2 (Oregon) — DEV source: 10.33.0.194

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|:-----------:|:------------:|:------:|
| euw2-dev cell1000 | 10.1.0.148 | inter-region | 0% | 129.25 | PASS |
| euw1-dev cell3000 | 10.17.0.7 | inter-region | 0% | 119.22 | PASS |
| use1-dev cell7000 | 10.49.0.187 | inter-region | 0% | 56.97 | PASS |
| usw2-dev cell5001 | 10.33.16.146 | intra-region | 0% | 1.22 | PASS |

### us-east-1 (N. Virginia) — PROD source: 10.48.0.248

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|:-----------:|:------------:|:------:|
| euw2-prod cell0000 | 10.0.0.31 | inter-region | 0% | 77.10 | PASS |
| euw1-prod cell2000 | 10.16.0.24 | inter-region | 0% | 69.28 | PASS |
| usw2-prod cell4000 | 10.32.0.203 | inter-region | 0% | 57.21 | PASS |
| use1-prod cell6001 | 10.48.16.82 | intra-region | 0% | 1.05 | PASS |

### us-east-1 (N. Virginia) — DEV source: 10.49.0.187

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|:-----------:|:------------:|:------:|
| euw2-dev cell1000 | 10.1.0.148 | inter-region | 0% | 76.27 | PASS |
| euw1-dev cell3000 | 10.17.0.7 | inter-region | 0% | 67.91 | PASS |
| usw2-dev cell5000 | 10.33.0.194 | inter-region | 0% | 56.48 | PASS |
| use1-dev cell7001 | 10.49.16.80 | intra-region | 0% | 1.35 | PASS |

---

## RTT Observations

| Path | Avg RTT | Notes |
|------|--------:|-------|
| Intra-region (any) | ~1 ms | Local TGW routing, no peering traversal |
| euw2 ↔ euw1 (London ↔ Dublin) | ~12–13 ms | Nearest inter-region pair |
| use1 ↔ usw2 (N. Virginia ↔ Oregon) | ~57 ms | US cross-country |
| use1 ↔ euw1 (N. Virginia ↔ Dublin) | ~69 ms | Transatlantic |
| use1 ↔ euw2 (N. Virginia ↔ London) | ~77 ms | Transatlantic |
| euw1 ↔ usw2 (Dublin ↔ Oregon) | ~118–119 ms | Transatlantic + US cross-country |
| euw2 ↔ usw2 (London ↔ Oregon) | ~128–132 ms | Longest path |

RTTs are symmetric between prod and dev, confirming identical TGW routing for both environments.

## Prod/Dev Isolation

Not tested in this run (requires deliberate cross-env ping). TGW route table design enforces isolation at the routing layer — prod VPCs attach to the prod route table, dev VPCs to the dev route table, with no cross-table routes.
