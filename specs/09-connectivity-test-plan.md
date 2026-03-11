# Spec 09 — SSH Connectivity Testing for the 4-Region Global Network

**Status**: Complete — 32/32 PASS (2026-02-27). See [conn-results-summary.md](./conn-results-summary.md)

---

## Overview

This plan describes how to SSH into EC2 instances across all 16 VPC cells in the
4-region AWS global network, and perform end-to-end connectivity tests between
private hosts across regions and environments. The network uses Transit Gateway
(TGW) peering for cross-region routing and separate TGW route tables to enforce
prod/dev isolation.

---

## Part 1: Gather Instance IPs

### 1.1 Generate instances.json

Run the following command from the repo root. Use `--json-only` when the
Terraform state is already up to date (fastest). Use `--json-refresh` if the
state may be stale — for example if instances were stopped/started and received
new public IPs.

```bash
# Fast path — reads existing Terraform state, no AWS API calls beyond terraform output
python scripts/deploy.py --json-only

# If state might be stale (e.g. after instance restart or EIP reassignment):
python scripts/deploy.py --json-refresh
```

Both flags skip the full deploy pipeline and write `instances.json` to the repo
root. `--json-refresh` additionally runs `terraform apply -refresh-only
-auto-approve` on each cell directory before collecting outputs, which synchronises
the local state file with the live AWS state (public IPs, instance IDs, etc.).

The `--json-only` / `--json-refresh` flags accept the same `--environment` and
`--regions` filters as a normal deploy, so you can scope collection:

```bash
# Collect only eu-west-2 cells
python scripts/deploy.py --json-only --regions euw2

# Collect all prod cells across all regions
python scripts/deploy.py --json-only --environment prod
```

### 1.2 instances.json Structure

The file is written to `<repo-root>/instances.json` and has the following shape.
Keys are the relative Terraform cell directory paths. Each cell has two sub-maps:

- `bastions` — map of bastion name → public IP (used as jump host)
- `private_hosts` — map of private host name → private IP (target for ping tests)

```json
{
  "envs/prod/euw2/cell0000": {
    "bastions": {
      "bastion-euw2-prod-pub-0-cell0000": "3.9.118.240"
    },
    "private_hosts": {
      "private-euw2-prod-priv-1-cell0000": "10.0.0.69"
    }
  },
  "envs/prod/euw2/cell0001": {
    "bastions": {
      "bastion-euw2-prod-pub-0-cell0001": "<public-ip>"
    },
    "private_hosts": {
      "private-euw2-prod-priv-1-cell0001": "10.0.16.x"
    }
  },
  "envs/dev/euw2/cell1000": {
    "bastions": {
      "bastion-euw2-dev-pub-0-cell1000": "<public-ip>"
    },
    "private_hosts": {
      "private-euw2-dev-priv-1-cell1000": "10.1.0.x"
    }
  },
  "... (16 cells total)": "..."
}
```

### 1.3 Parse instances.json to Extract IPs

```bash
# All bastion public IPs
python3 -c "
import json
data = json.load(open('instances.json'))
for cell_path, cell in sorted(data.items()):
    for name, ip in cell.get('bastions', {}).items():
        print(f'{name}: {ip}')
"

# All private host IPs
python3 -c "
import json
data = json.load(open('instances.json'))
for cell_path, cell in sorted(data.items()):
    for name, ip in cell.get('private_hosts', {}).items():
        print(f'{name}: {ip}')
"
```

---

## Part 2: SSH Access Strategy

### 2.1 Architecture

- Bastions live in public subnets and have public IPs. They are the SSH entry point.
- Private hosts live in private subnets with no public IP. They are reached by
  hopping through the bastion.
- SSH agent forwarding (`-A`) is used so the private host SSH connection can use
  your local SSH key without copying it to the bastion.
- We only need one bastion per region/environment pair — the one in the first
  cell (cell X000).

### 2.2 Key File Reference

| Environment | Key file |
|-------------|----------|
| euw2-prod | `ssh-keys/euw2-prod.pem` |
| euw2-dev | `ssh-keys/euw2-dev.pem` |
| euw1-prod | `ssh-keys/euw1-prod.pem` |
| euw1-dev | `ssh-keys/euw1-dev.pem` |
| usw2-prod | `ssh-keys/usw2-prod.pem` |
| usw2-dev | `ssh-keys/usw2-dev.pem` |
| use1-prod | `ssh-keys/use1-prod.pem` |
| use1-dev | `ssh-keys/use1-dev.pem` |

### 2.3 SSH Command Pattern

```bash
# Step 1 — SSH to bastion with agent forwarding
ssh -A -i ssh-keys/{region}-{env}.pem ubuntu@<bastion-public-ip>

# Step 2 — From bastion, jump to private host
ssh ubuntu@<private-host-ip>
```

### 2.4 SSH Commands for All 8 Environments

#### euw2-prod (bastion in cell0000)
```bash
ssh -A -i ssh-keys/euw2-prod.pem ubuntu@<bastion-euw2-prod-pub-0-cell0000-ip>
  # then: ssh ubuntu@<private-euw2-prod-priv-1-cell0000-ip>
```

#### euw2-dev (bastion in cell1000)
```bash
ssh -A -i ssh-keys/euw2-dev.pem ubuntu@<bastion-euw2-dev-pub-0-cell1000-ip>
  # then: ssh ubuntu@<private-euw2-dev-priv-1-cell1000-ip>
```

#### euw1-prod (bastion in cell2000)
```bash
ssh -A -i ssh-keys/euw1-prod.pem ubuntu@<bastion-euw1-prod-pub-0-cell2000-ip>
  # then: ssh ubuntu@<private-euw1-prod-priv-1-cell2000-ip>
```

#### euw1-dev (bastion in cell3000)
```bash
ssh -A -i ssh-keys/euw1-dev.pem ubuntu@<bastion-euw1-dev-pub-0-cell3000-ip>
  # then: ssh ubuntu@<private-euw1-dev-priv-1-cell3000-ip>
```

#### usw2-prod (bastion in cell4000)
```bash
ssh -A -i ssh-keys/usw2-prod.pem ubuntu@<bastion-usw2-prod-pub-0-cell4000-ip>
  # then: ssh ubuntu@<private-usw2-prod-priv-1-cell4000-ip>
```

#### usw2-dev (bastion in cell5000)
```bash
ssh -A -i ssh-keys/usw2-dev.pem ubuntu@<bastion-usw2-dev-pub-0-cell5000-ip>
  # then: ssh ubuntu@<private-usw2-dev-priv-1-cell5000-ip>
```

#### use1-prod (bastion in cell6000)
```bash
ssh -A -i ssh-keys/use1-prod.pem ubuntu@<bastion-use1-prod-pub-0-cell6000-ip>
  # then: ssh ubuntu@<private-use1-prod-priv-1-cell6000-ip>
```

#### use1-dev (bastion in cell7000)
```bash
ssh -A -i ssh-keys/use1-dev.pem ubuntu@<bastion-use1-dev-pub-0-cell7000-ip>
  # then: ssh ubuntu@<private-use1-dev-priv-1-cell7000-ip>
```

---

## Part 3: Pre-flight Checks

### 3.1 Fix Key File Permissions

```bash
chmod 400 ssh-keys/*.pem
ls -l ssh-keys/  # Expected: -r-------- (400) for all .pem files
```

### 3.2 Verify instances.json Has All 16 Cells

```bash
python3 -c "
import json
data = json.load(open('instances.json'))
print(f'Cells found: {len(data)}')
for k in sorted(data.keys()):
    b = list(data[k].get('bastions', {}).values())
    p = list(data[k].get('private_hosts', {}).values())
    print(f'  {k}: bastion={b[0] if b else \"MISSING\"}, private={p[0] if p else \"MISSING\"}')
"
# Expected: Cells found: 16
```

### 3.3 Verify SSH Connectivity to Each Bastion

```bash
# Quick connectivity smoke test for each bastion
ssh -A -i ssh-keys/euw2-prod.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@<ip> "echo euw2-prod OK"
ssh -A -i ssh-keys/euw2-dev.pem  -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@<ip> "echo euw2-dev OK"
ssh -A -i ssh-keys/euw1-prod.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@<ip> "echo euw1-prod OK"
ssh -A -i ssh-keys/euw1-dev.pem  -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@<ip> "echo euw1-dev OK"
ssh -A -i ssh-keys/usw2-prod.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@<ip> "echo usw2-prod OK"
ssh -A -i ssh-keys/usw2-dev.pem  -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@<ip> "echo usw2-dev OK"
ssh -A -i ssh-keys/use1-prod.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@<ip> "echo use1-prod OK"
ssh -A -i ssh-keys/use1-dev.pem  -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@<ip> "echo use1-dev OK"
```

---

---

## Part 4: Test Matrix — PROD

Each of the four prod private hosts acts as a source. From each source the tester pings every other prod private host — both in remote regions and the local intra-region peer cell. IPs are obtained at test time from `instances.json`.

### 4.1 Access chain for every prod source

```
Operator machine
  └─ ssh -A -i ssh-keys/<region>-prod.pem ubuntu@<bastion-public-ip>
       └─ ssh ubuntu@<private-host-private-ip>
            └─ ping -c 4 <target-private-ip>
```

### 4.2 Source: private-euw2-prod-priv-1-cell0000 (eu-west-2)

- Bastion: `bastion-euw2-prod-pub-0-cell0000` · Key: `ssh-keys/euw2-prod.pem`

| # | Target | CIDR | Relationship |
|---|--------|------|--------------|
| 1 | private-euw1-prod-priv-1-cell2000 | 10.16.1.x | inter-region (euw1) |
| 2 | private-usw2-prod-priv-1-cell4000 | 10.32.1.x | inter-region (usw2) |
| 3 | private-use1-prod-priv-1-cell6000 | 10.48.1.x | inter-region (use1) |
| 4 | private-euw2-prod-priv-1-cell0001 | 10.0.17.x | intra-region peer cell |

```bash
ping -c 4 <cell2000-private-ip>   # euw1 prod
ping -c 4 <cell4000-private-ip>   # usw2 prod
ping -c 4 <cell6000-private-ip>   # use1 prod
ping -c 4 <cell0001-private-ip>   # euw2 prod intra-region
```

### 4.3 Source: private-euw1-prod-priv-1-cell2000 (eu-west-1)

- Bastion: `bastion-euw1-prod-pub-0-cell2000` · Key: `ssh-keys/euw1-prod.pem`

| # | Target | CIDR | Relationship |
|---|--------|------|--------------|
| 1 | private-euw2-prod-priv-1-cell0000 | 10.0.1.x | inter-region (euw2) |
| 2 | private-usw2-prod-priv-1-cell4000 | 10.32.1.x | inter-region (usw2) |
| 3 | private-use1-prod-priv-1-cell6000 | 10.48.1.x | inter-region (use1) |
| 4 | private-euw1-prod-priv-1-cell2001 | 10.16.17.x | intra-region peer cell |

```bash
ping -c 4 <cell0000-private-ip>   # euw2 prod
ping -c 4 <cell4000-private-ip>   # usw2 prod
ping -c 4 <cell6000-private-ip>   # use1 prod
ping -c 4 <cell2001-private-ip>   # euw1 prod intra-region
```

### 4.4 Source: private-usw2-prod-priv-1-cell4000 (us-west-2)

- Bastion: `bastion-usw2-prod-pub-0-cell4000` · Key: `ssh-keys/usw2-prod.pem`

| # | Target | CIDR | Relationship |
|---|--------|------|--------------|
| 1 | private-euw2-prod-priv-1-cell0000 | 10.0.1.x | inter-region (euw2) |
| 2 | private-euw1-prod-priv-1-cell2000 | 10.16.1.x | inter-region (euw1) |
| 3 | private-use1-prod-priv-1-cell6000 | 10.48.1.x | inter-region (use1) |
| 4 | private-usw2-prod-priv-1-cell4001 | 10.32.17.x | intra-region peer cell |

```bash
ping -c 4 <cell0000-private-ip>   # euw2 prod
ping -c 4 <cell2000-private-ip>   # euw1 prod
ping -c 4 <cell6000-private-ip>   # use1 prod
ping -c 4 <cell4001-private-ip>   # usw2 prod intra-region
```

### 4.5 Source: private-use1-prod-priv-1-cell6000 (us-east-1)

- Bastion: `bastion-use1-prod-pub-0-cell6000` · Key: `ssh-keys/use1-prod.pem`

| # | Target | CIDR | Relationship |
|---|--------|------|--------------|
| 1 | private-euw2-prod-priv-1-cell0000 | 10.0.1.x | inter-region (euw2) |
| 2 | private-euw1-prod-priv-1-cell2000 | 10.16.1.x | inter-region (euw1) |
| 3 | private-usw2-prod-priv-1-cell4000 | 10.32.1.x | inter-region (usw2) |
| 4 | private-use1-prod-priv-1-cell6001 | 10.48.17.x | intra-region peer cell |

```bash
ping -c 4 <cell0000-private-ip>   # euw2 prod
ping -c 4 <cell2000-private-ip>   # euw1 prod
ping -c 4 <cell4000-private-ip>   # usw2 prod
ping -c 4 <cell6001-private-ip>   # use1 prod intra-region
```

---

## Part 5: Test Matrix — DEV

### 5.1 Access chain for every dev source

```
Operator machine
  └─ ssh -A -i ssh-keys/<region>-dev.pem ubuntu@<bastion-public-ip>
       └─ ssh ubuntu@<private-host-private-ip>
            └─ ping -c 4 <target-private-ip>
```

### 5.2 Source: private-euw2-dev-priv-1-cell1000 (eu-west-2)

- Bastion: `bastion-euw2-dev-pub-0-cell1000` · Key: `ssh-keys/euw2-dev.pem`

| # | Target | CIDR | Relationship |
|---|--------|------|--------------|
| 1 | private-euw1-dev-priv-1-cell3000 | 10.17.1.x | inter-region (euw1) |
| 2 | private-usw2-dev-priv-1-cell5000 | 10.33.1.x | inter-region (usw2) |
| 3 | private-use1-dev-priv-1-cell7000 | 10.49.1.x | inter-region (use1) |
| 4 | private-euw2-dev-priv-1-cell1001 | 10.1.17.x | intra-region peer cell |

```bash
ping -c 4 <cell3000-private-ip>   # euw1 dev
ping -c 4 <cell5000-private-ip>   # usw2 dev
ping -c 4 <cell7000-private-ip>   # use1 dev
ping -c 4 <cell1001-private-ip>   # euw2 dev intra-region
```

### 5.3 Source: private-euw1-dev-priv-1-cell3000 (eu-west-1)

- Bastion: `bastion-euw1-dev-pub-0-cell3000` · Key: `ssh-keys/euw1-dev.pem`

| # | Target | CIDR | Relationship |
|---|--------|------|--------------|
| 1 | private-euw2-dev-priv-1-cell1000 | 10.1.1.x | inter-region (euw2) |
| 2 | private-usw2-dev-priv-1-cell5000 | 10.33.1.x | inter-region (usw2) |
| 3 | private-use1-dev-priv-1-cell7000 | 10.49.1.x | inter-region (use1) |
| 4 | private-euw1-dev-priv-1-cell3001 | 10.17.17.x | intra-region peer cell |

```bash
ping -c 4 <cell1000-private-ip>   # euw2 dev
ping -c 4 <cell5000-private-ip>   # usw2 dev
ping -c 4 <cell7000-private-ip>   # use1 dev
ping -c 4 <cell3001-private-ip>   # euw1 dev intra-region
```

### 5.4 Source: private-usw2-dev-priv-1-cell5000 (us-west-2)

- Bastion: `bastion-usw2-dev-pub-0-cell5000` · Key: `ssh-keys/usw2-dev.pem`

| # | Target | CIDR | Relationship |
|---|--------|------|--------------|
| 1 | private-euw2-dev-priv-1-cell1000 | 10.1.1.x | inter-region (euw2) |
| 2 | private-euw1-dev-priv-1-cell3000 | 10.17.1.x | inter-region (euw1) |
| 3 | private-use1-dev-priv-1-cell7000 | 10.49.1.x | inter-region (use1) |
| 4 | private-usw2-dev-priv-1-cell5001 | 10.33.17.x | intra-region peer cell |

```bash
ping -c 4 <cell1000-private-ip>   # euw2 dev
ping -c 4 <cell3000-private-ip>   # euw1 dev
ping -c 4 <cell7000-private-ip>   # use1 dev
ping -c 4 <cell5001-private-ip>   # usw2 dev intra-region
```

### 5.5 Source: private-use1-dev-priv-1-cell7000 (us-east-1)

- Bastion: `bastion-use1-dev-pub-0-cell7000` · Key: `ssh-keys/use1-dev.pem`

| # | Target | CIDR | Relationship |
|---|--------|------|--------------|
| 1 | private-euw2-dev-priv-1-cell1000 | 10.1.1.x | inter-region (euw2) |
| 2 | private-euw1-dev-priv-1-cell3000 | 10.17.1.x | inter-region (euw1) |
| 3 | private-usw2-dev-priv-1-cell5000 | 10.33.1.x | inter-region (usw2) |
| 4 | private-use1-dev-priv-1-cell7001 | 10.49.17.x | intra-region peer cell |

```bash
ping -c 4 <cell1000-private-ip>   # euw2 dev
ping -c 4 <cell3000-private-ip>   # euw1 dev
ping -c 4 <cell5000-private-ip>   # usw2 dev
ping -c 4 <cell7001-private-ip>   # use1 dev intra-region
```

---

## Part 6: Expected Results Table

All same-env pings must PASS. Cross-env pings must FAIL (TGW route table isolation).
**Total expected-PASS tests: 32 (16 prod + 16 dev)**

| Source Cell | Target Cell | Env | Type | Expected |
|---|---|---|---|---|
| cell0000 (euw2-prod) | cell2000 (euw1-prod) | Prod | inter-region | PASS |
| cell0000 (euw2-prod) | cell4000 (usw2-prod) | Prod | inter-region | PASS |
| cell0000 (euw2-prod) | cell6000 (use1-prod) | Prod | inter-region | PASS |
| cell0000 (euw2-prod) | cell0001 (euw2-prod) | Prod | intra-region | PASS |
| cell2000 (euw1-prod) | cell0000 (euw2-prod) | Prod | inter-region | PASS |
| cell2000 (euw1-prod) | cell4000 (usw2-prod) | Prod | inter-region | PASS |
| cell2000 (euw1-prod) | cell6000 (use1-prod) | Prod | inter-region | PASS |
| cell2000 (euw1-prod) | cell2001 (euw1-prod) | Prod | intra-region | PASS |
| cell4000 (usw2-prod) | cell0000 (euw2-prod) | Prod | inter-region | PASS |
| cell4000 (usw2-prod) | cell2000 (euw1-prod) | Prod | inter-region | PASS |
| cell4000 (usw2-prod) | cell6000 (use1-prod) | Prod | inter-region | PASS |
| cell4000 (usw2-prod) | cell4001 (usw2-prod) | Prod | intra-region | PASS |
| cell6000 (use1-prod) | cell0000 (euw2-prod) | Prod | inter-region | PASS |
| cell6000 (use1-prod) | cell2000 (euw1-prod) | Prod | inter-region | PASS |
| cell6000 (use1-prod) | cell4000 (usw2-prod) | Prod | inter-region | PASS |
| cell6000 (use1-prod) | cell6001 (use1-prod) | Prod | intra-region | PASS |
| cell1000 (euw2-dev) | cell3000 (euw1-dev) | Dev | inter-region | PASS |
| cell1000 (euw2-dev) | cell5000 (usw2-dev) | Dev | inter-region | PASS |
| cell1000 (euw2-dev) | cell7000 (use1-dev) | Dev | inter-region | PASS |
| cell1000 (euw2-dev) | cell1001 (euw2-dev) | Dev | intra-region | PASS |
| cell3000 (euw1-dev) | cell1000 (euw2-dev) | Dev | inter-region | PASS |
| cell3000 (euw1-dev) | cell5000 (usw2-dev) | Dev | inter-region | PASS |
| cell3000 (euw1-dev) | cell7000 (use1-dev) | Dev | inter-region | PASS |
| cell3000 (euw1-dev) | cell3001 (euw1-dev) | Dev | intra-region | PASS |
| cell5000 (usw2-dev) | cell1000 (euw2-dev) | Dev | inter-region | PASS |
| cell5000 (usw2-dev) | cell3000 (euw1-dev) | Dev | inter-region | PASS |
| cell5000 (usw2-dev) | cell7000 (use1-dev) | Dev | inter-region | PASS |
| cell5000 (usw2-dev) | cell5001 (usw2-dev) | Dev | intra-region | PASS |
| cell7000 (use1-dev) | cell1000 (euw2-dev) | Dev | inter-region | PASS |
| cell7000 (use1-dev) | cell3000 (euw1-dev) | Dev | inter-region | PASS |
| cell7000 (use1-dev) | cell5000 (usw2-dev) | Dev | inter-region | PASS |
| cell7000 (use1-dev) | cell7001 (use1-dev) | Dev | intra-region | PASS |
| *any prod cell* | *any dev cell* | Cross-env | N/A | FAIL (TGW isolation) |
| *any dev cell* | *any prod cell* | Cross-env | N/A | FAIL (TGW isolation) |

---

## Part 7: Results Recording Template

Fill in as tests are executed. RTT from the `avg` field in ping summary line.

| Source | Target | Env | Expected | Actual | RTT (ms avg) | Status | Notes |
|---|---|---|---|---|---|---|---|
| cell0000 (euw2-prod) | cell2000 (euw1-prod) | Prod | PASS | | | | |
| cell0000 (euw2-prod) | cell4000 (usw2-prod) | Prod | PASS | | | | |
| cell0000 (euw2-prod) | cell6000 (use1-prod) | Prod | PASS | | | | |
| cell0000 (euw2-prod) | cell0001 (euw2-prod) | Prod | PASS | | | | |
| cell2000 (euw1-prod) | cell0000 (euw2-prod) | Prod | PASS | | | | |
| cell2000 (euw1-prod) | cell4000 (usw2-prod) | Prod | PASS | | | | |
| cell2000 (euw1-prod) | cell6000 (use1-prod) | Prod | PASS | | | | |
| cell2000 (euw1-prod) | cell2001 (euw1-prod) | Prod | PASS | | | | |
| cell4000 (usw2-prod) | cell0000 (euw2-prod) | Prod | PASS | | | | |
| cell4000 (usw2-prod) | cell2000 (euw1-prod) | Prod | PASS | | | | |
| cell4000 (usw2-prod) | cell6000 (use1-prod) | Prod | PASS | | | | |
| cell4000 (usw2-prod) | cell4001 (usw2-prod) | Prod | PASS | | | | |
| cell6000 (use1-prod) | cell0000 (euw2-prod) | Prod | PASS | | | | |
| cell6000 (use1-prod) | cell2000 (euw1-prod) | Prod | PASS | | | | |
| cell6000 (use1-prod) | cell4000 (usw2-prod) | Prod | PASS | | | | |
| cell6000 (use1-prod) | cell6001 (use1-prod) | Prod | PASS | | | | |
| cell1000 (euw2-dev) | cell3000 (euw1-dev) | Dev | PASS | | | | |
| cell1000 (euw2-dev) | cell5000 (usw2-dev) | Dev | PASS | | | | |
| cell1000 (euw2-dev) | cell7000 (use1-dev) | Dev | PASS | | | | |
| cell1000 (euw2-dev) | cell1001 (euw2-dev) | Dev | PASS | | | | |
| cell3000 (euw1-dev) | cell1000 (euw2-dev) | Dev | PASS | | | | |
| cell3000 (euw1-dev) | cell5000 (usw2-dev) | Dev | PASS | | | | |
| cell3000 (euw1-dev) | cell7000 (use1-dev) | Dev | PASS | | | | |
| cell3000 (euw1-dev) | cell3001 (euw1-dev) | Dev | PASS | | | | |
| cell5000 (usw2-dev) | cell1000 (euw2-dev) | Dev | PASS | | | | |
| cell5000 (usw2-dev) | cell3000 (euw1-dev) | Dev | PASS | | | | |
| cell5000 (usw2-dev) | cell7000 (use1-dev) | Dev | PASS | | | | |
| cell5000 (usw2-dev) | cell5001 (usw2-dev) | Dev | PASS | | | | |
| cell7000 (use1-dev) | cell1000 (euw2-dev) | Dev | PASS | | | | |
| cell7000 (use1-dev) | cell3000 (euw1-dev) | Dev | PASS | | | | |
| cell7000 (use1-dev) | cell5000 (usw2-dev) | Dev | PASS | | | | |
| cell7000 (use1-dev) | cell7001 (use1-dev) | Dev | PASS | | | | |

**Legend:** Actual = PASS (0% loss) | FAIL (any loss) | TIMEOUT (SSH unreachable)

---

## Part 8: Automated Test Script

`scripts/connectivity-test.sh` — logical outline; sources `instances.json` for all IPs.

```bash
#!/usr/bin/env bash
# connectivity-test.sh
# Usage: bash scripts/connectivity-test.sh [--env prod|dev|all] [--output results.md]
# Exit 0 = all passed, exit 1 = one or more failures

# Step 1: Validate instances.json exists
#   If missing: abort with "run python scripts/deploy.py --json-only"

# Step 2: Define IP helpers
#   get_bastion_ip(cell_dir)  → jq -r '."<cell_dir>".bastions | to_entries[0].value' instances.json
#   get_private_ip(cell_dir)  → jq -r '."<cell_dir>".private_hosts | to_entries[0].value' instances.json

# Step 3: Test matrix (source → targets)
#   PROD:
#     envs/prod/euw2/cell0000  euw2-prod  → [euw1/cell2000, usw2/cell4000, use1/cell6000, euw2/cell0001]
#     envs/prod/euw1/cell2000  euw1-prod  → [euw2/cell0000, usw2/cell4000, use1/cell6000, euw1/cell2001]
#     envs/prod/usw2/cell4000  usw2-prod  → [euw2/cell0000, euw1/cell2000, use1/cell6000, usw2/cell4001]
#     envs/prod/use1/cell6000  use1-prod  → [euw2/cell0000, euw1/cell2000, usw2/cell4000, use1/cell6001]
#   DEV:
#     envs/dev/euw2/cell1000   euw2-dev   → [euw1/cell3000, usw2/cell5000, use1/cell7000, euw2/cell1001]
#     envs/dev/euw1/cell3000   euw1-dev   → [euw2/cell1000, usw2/cell5000, use1/cell7000, euw1/cell3001]
#     envs/dev/usw2/cell5000   usw2-dev   → [euw2/cell1000, euw1/cell3000, use1/cell7000, usw2/cell5001]
#     envs/dev/use1/cell7000   use1-dev   → [euw2/cell1000, euw1/cell3000, usw2/cell5000, use1/cell7001]

# Step 4: For each source:
#   BASTION_IP=$(get_bastion_ip "$SOURCE_CELL_DIR")
#   SRC_PRIVATE_IP=$(get_private_ip "$SOURCE_CELL_DIR")
#   For each target:
#     TARGET_IP=$(get_private_ip "$TARGET_CELL_DIR")
#     OUTPUT=$(ssh -A -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
#                  -i "ssh-keys/${SSH_KEY}.pem" "ubuntu@${BASTION_IP}" \
#              "ssh -o StrictHostKeyChecking=no ubuntu@${SRC_PRIVATE_IP} \
#               'ping -c 4 ${TARGET_IP}'")
#     LOSS=$(echo "$OUTPUT" | grep -oP '\d+(?=% packet loss)')
#     RTT=$(echo "$OUTPUT"  | grep -oP 'avg[/ =]+\K[\d.]+' || echo "N/A")
#     STATUS=$( [ "$LOSS" == "0" ] && echo PASS || echo FAIL )
#     echo "| ${SOURCE} | ${TARGET} | ${STATUS} | ${RTT} ms |" >> results.log

# Step 5: Print PASS/FAIL summary; exit 1 if any failures
```

### Expected RTT benchmarks (approximate)

| Route | Expected RTT |
|-------|-------------|
| Intra-region (same TGW) | < 5 ms |
| euw2 ↔ euw1 (London ↔ Dublin) | ~10–15 ms |
| euw2/euw1 ↔ usw2 (London/Dublin ↔ Oregon) | ~130–170 ms |
| euw2/euw1 ↔ use1 (London/Dublin ↔ N. Virginia) | ~80–100 ms |
| usw2 ↔ use1 (Oregon ↔ N. Virginia) | ~65–75 ms |

### Known failures from prior testing (conn-tests.md)

- `cell2000 → cell2001` (euw1 intra-region prod) — previously reported as failing; verify TGW prod route table has `10.16.16.0/20` route.
- `cell2000 (euw1) → cell0000/cell0001 (euw2)` — previously failing; likely resolved by spec 08 full-mesh peering. Confirm TGW peering attachments are in `available` state.

### Failure triage checklist

- [ ] Security group `cross_region_supernet_cidrs` in `security.tf` covers source CIDR (`10.0.0.0/8`)
- [ ] Private NACL allows inbound/outbound for `10.0.0.0/8` (rules starting at 130 in `modules/security/nacls.tf`)
- [ ] TGW prod/dev route table has static route for destination /16 via the correct peering attachment
- [ ] TGW peering attachment state is `available` (not `pending`, `modifying`)

---

## Execution Checklist

```text
[ ] 1. python scripts/deploy.py --json-only          # generate instances.json
[ ] 2. chmod 400 ssh-keys/*.pem                       # fix key permissions
[ ] 3. Verify 16 cells in instances.json              # (see Part 3.2)
[ ] 4. SSH smoke test all 8 bastions                  # (see Part 3.3)
[ ] 5. PROD tests (Parts 4.2–4.5) — 16 pings total
[ ] 6. DEV tests (Parts 5.2–5.5)  — 16 pings total
[ ] 7. Fill in Part 7 results table
[ ] 8. Update specs/index.md status when all 32 pass
```
