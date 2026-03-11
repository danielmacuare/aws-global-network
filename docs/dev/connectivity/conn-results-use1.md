# Connectivity Test Results — us-east-1 (use1)

**Date:** 2026-02-27
**Tested from:** use1 (N. Virginia)
**Method:** `ping -c 4` via SSH ProxyJump through bastion hosts

## PROD — Source: private-use1-prod-priv-0-cell6000 (10.48.0.248)

Bastion: `44.204.203.139` | Key: `ssh-keys/use1-prod.pem`

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|-------------|--------------|--------|
| euw2-prod cell0000 | 10.0.0.31 | inter-region | 0% | 77.10 | PASS |
| euw1-prod cell2000 | 10.16.0.24 | inter-region | 0% | 69.28 | PASS |
| usw2-prod cell4000 | 10.32.0.203 | inter-region | 0% | 57.21 | PASS |
| use1-prod cell6001 | 10.48.16.82 | intra-region | 0% | 1.05 | PASS |

## DEV — Source: private-use1-dev-priv-0-cell7000 (10.49.0.187)

Bastion: `34.200.233.116` | Key: `ssh-keys/use1-dev.pem`

| Target | Target IP | Type | Packet Loss | RTT avg (ms) | Status |
|--------|-----------|------|-------------|--------------|--------|
| euw2-dev cell1000 | 10.1.0.148 | inter-region | 0% | 76.27 | PASS |
| euw1-dev cell3000 | 10.17.0.7 | inter-region | 0% | 67.91 | PASS |
| usw2-dev cell5000 | 10.33.0.194 | inter-region | 0% | 56.48 | PASS |
| use1-dev cell7001 | 10.49.16.80 | intra-region | 0% | 1.35 | PASS |

## Raw Ping Output

### PROD Test 1 — euw2-prod cell0000 (10.0.0.31)

```
PING 10.0.0.31 (10.0.0.31) 56(84) bytes of data.
64 bytes from 10.0.0.31: icmp_seq=1 ttl=62 time=78.2 ms
64 bytes from 10.0.0.31: icmp_seq=2 ttl=62 time=76.9 ms
64 bytes from 10.0.0.31: icmp_seq=3 ttl=62 time=76.5 ms
64 bytes from 10.0.0.31: icmp_seq=4 ttl=62 time=76.7 ms

--- 10.0.0.31 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 76.520/77.097/78.201/0.653 ms
```

### PROD Test 2 — euw1-prod cell2000 (10.16.0.24)

```
PING 10.16.0.24 (10.16.0.24) 56(84) bytes of data.
64 bytes from 10.16.0.24: icmp_seq=1 ttl=62 time=71.0 ms
64 bytes from 10.16.0.24: icmp_seq=2 ttl=62 time=68.5 ms
64 bytes from 10.16.0.24: icmp_seq=3 ttl=62 time=68.7 ms
64 bytes from 10.16.0.24: icmp_seq=4 ttl=62 time=68.9 ms

--- 10.16.0.24 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3002ms
rtt min/avg/max/mdev = 68.521/69.284/70.997/0.999 ms
```

### PROD Test 3 — usw2-prod cell4000 (10.32.0.203)

```
PING 10.32.0.203 (10.32.0.203) 56(84) bytes of data.
64 bytes from 10.32.0.203: icmp_seq=1 ttl=62 time=58.9 ms
64 bytes from 10.32.0.203: icmp_seq=2 ttl=62 time=56.7 ms
64 bytes from 10.32.0.203: icmp_seq=3 ttl=62 time=56.6 ms
64 bytes from 10.32.0.203: icmp_seq=4 ttl=62 time=56.6 ms

--- 10.32.0.203 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 56.593/57.205/58.922/0.992 ms
```

### PROD Test 4 — use1-prod cell6001 (10.48.16.82)

```
PING 10.48.16.82 (10.48.16.82) 56(84) bytes of data.
64 bytes from 10.48.16.82: icmp_seq=1 ttl=63 time=1.91 ms
64 bytes from 10.48.16.82: icmp_seq=2 ttl=63 time=0.570 ms
64 bytes from 10.48.16.82: icmp_seq=3 ttl=63 time=0.595 ms
64 bytes from 10.48.16.82: icmp_seq=4 ttl=63 time=1.14 ms

--- 10.48.16.82 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3063ms
rtt min/avg/max/mdev = 0.570/1.051/1.907/0.542 ms
```

### DEV Test 1 — euw2-dev cell1000 (10.1.0.148)

```
PING 10.1.0.148 (10.1.0.148) 56(84) bytes of data.
64 bytes from 10.1.0.148: icmp_seq=1 ttl=62 time=77.3 ms
64 bytes from 10.1.0.148: icmp_seq=2 ttl=62 time=75.8 ms
64 bytes from 10.1.0.148: icmp_seq=3 ttl=62 time=76.0 ms
64 bytes from 10.1.0.148: icmp_seq=4 ttl=62 time=76.0 ms

--- 10.1.0.148 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 75.782/76.272/77.342/0.623 ms
```

### DEV Test 2 — euw1-dev cell3000 (10.17.0.7)

```
PING 10.17.0.7 (10.17.0.7) 56(84) bytes of data.
64 bytes from 10.17.0.7: icmp_seq=1 ttl=62 time=69.7 ms
64 bytes from 10.17.0.7: icmp_seq=2 ttl=62 time=67.3 ms
64 bytes from 10.17.0.7: icmp_seq=3 ttl=62 time=67.3 ms
64 bytes from 10.17.0.7: icmp_seq=4 ttl=62 time=67.4 ms

--- 10.17.0.7 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
rtt min/avg/max/mdev = 67.288/67.914/69.657/1.006 ms
```

### DEV Test 3 — usw2-dev cell5000 (10.33.0.194)

```
PING 10.33.0.194 (10.33.0.194) 56(84) bytes of data.
64 bytes from 10.33.0.194: icmp_seq=1 ttl=62 time=57.9 ms
64 bytes from 10.33.0.194: icmp_seq=2 ttl=62 time=56.0 ms
64 bytes from 10.33.0.194: icmp_seq=3 ttl=62 time=55.9 ms
64 bytes from 10.33.0.194: icmp_seq=4 ttl=62 time=56.2 ms

--- 10.33.0.194 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 55.885/56.482/57.874/0.809 ms
```

### DEV Test 4 — use1-dev cell7001 (10.49.16.80)

```
PING 10.49.16.80 (10.49.16.80) 56(84) bytes of data.
64 bytes from 10.49.16.80: icmp_seq=1 ttl=63 time=1.64 ms
64 bytes from 10.49.16.80: icmp_seq=2 ttl=63 time=0.604 ms
64 bytes from 10.49.16.80: icmp_seq=3 ttl=63 time=1.81 ms
64 bytes from 10.49.16.80: icmp_seq=4 ttl=63 time=1.36 ms

--- 10.49.16.80 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3009ms
rtt min/avg/max/mdev = 0.604/1.353/1.811/0.461 ms
```
