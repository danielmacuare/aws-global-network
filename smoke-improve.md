# Smoke Test Performance Analysis & Improvement Suggestions

## Current Execution Model

Everything runs **sequentially** at two levels:

### Level 1 — Source cells (Python loop)
```python
for src in cells:          # 8 dev + 8 prod cells
    run_cell_test(...)     # blocks until SSH session + all pings complete
```
Each `run_cell_test()` call holds the Python process hostage until the entire
SSH session finishes. No threading, no async, no concurrency.

### Level 2 — Remote pings (bash `;`)
```bash
ping -c 4 -W 5 10.1.0.20 && echo RESULT:PASS:... || echo RESULT:FAIL:...;
ping -c 4 -W 5 10.1.16.199 && echo RESULT:PASS:... || echo RESULT:FAIL:...;
...
```
Pings are chained with `;` so each one waits for the previous to finish
before starting.

---

## Worst-Case Timing (today)

| Layer | Count | Worst case per unit | Total |
|---|---|---|---|
| SSH handshake (bastion + private) | 16 cells | ~10 s | 160 s |
| Remote pings (all failing, `-W 5` × 4 packets) | 16 × 7 = 112 pairs | 20 s each | 2 240 s |
| **Grand total (sequential)** | | | **~40 min** |

Best case (all passing, low latency):
- SSH: 160 s + pings: 16 × 7 × ~1 s ≈ **4 min**

---

## Improvement 1 — Parallelize Remote Pings (Easiest, Big Win)

Replace the `;`-chained ping commands with bash background jobs + `wait`.
All pings fire simultaneously from the private host; total time becomes
the slowest single ping rather than the sum of all pings.

**Change in `run_cell_test()`:**

```python
# Instead of:
remote_cmd = "; ".join(ping_parts)

# Use background jobs:
bg_parts = [f"( {p} ) &" for p in ping_parts]
remote_cmd = " ".join(bg_parts) + " wait"
```

**Speedup:** 7× within each cell (7 pings in parallel instead of series).

**Worst-case timing after this change:**
- SSH: 160 s + pings: 16 × 20 s (one slow ping sets the pace) = **~6 min**
- Best case: **~3 min**

---

## Improvement 2 — Parallelize Source Cells (Biggest Win)

Run `run_cell_test()` for all source cells concurrently using
`concurrent.futures.ThreadPoolExecutor`. Each call is a blocking subprocess,
so threads are appropriate (no GIL issue for subprocess I/O wait).

```python
from concurrent.futures import ThreadPoolExecutor, as_completed

with ThreadPoolExecutor(max_workers=16) as pool:
    futures = {
        pool.submit(run_cell_test, src, dst_cells, key_dir, timeout, debug): src
        for src, dst_cells in work_items
    }
    for future in as_completed(futures):
        results = future.result()
        all_results.extend(results)
```

**Speedup:** ~8× (all 8 dev cells tested simultaneously; same for prod).

**Worst-case timing after improvements 1 + 2:**
- Max(SSH handshake) + Max(single ping) ≈ **10 s + 20 s = ~30 s**
- Best case: **~12 s**

**Caveat:** stdout output from concurrent cells will interleave. The live
progress prints (`-> euw2/cell1000 ... PASS`) need to be buffered per-cell
and flushed atomically (e.g. with a `threading.Lock` or by collecting all
output and printing after the future resolves).

---

## Improvement 3 — Add Timing to Results

Wrap each `run_cell_test()` call with `time.perf_counter()` and record
elapsed seconds per source cell. Surface this in the rich table as a
**Duration** column. This makes it easy to spot slow cells or regions.

```python
import time

start = time.perf_counter()
results = run_cell_test(...)
elapsed = time.perf_counter() - start

for r in results:
    r["duration"] = elapsed
```

Rich table addition:
```python
table.add_column("Duration", justify="right", no_wrap=True)
# row value: f"{r['duration']:.1f}s"
```

---

## Improvement 4 — Parallelize Remote Pings with RTT Capture

The current bash marker approach discards ping output. With background jobs
you can capture individual RTTs by writing to temp files:

```bash
ping -c 4 -W 5 10.1.0.20 > /tmp/r_euw2_cell1000 2>&1 &
ping -c 4 -W 5 10.1.16.199 > /tmp/r_euw2_cell1001 2>&1 &
wait
grep -q "bytes from" /tmp/r_euw2_cell1000 \
  && grep "rtt\|round-trip" /tmp/r_euw2_cell1000 | awk -F'/' '{print "RESULT:PASS:'euw2/cell1000':" $5 " ms"}' \
  || echo "RESULT:FAIL:euw2/cell1000:"
```

This restores the latency column in the results table.

---

## Improvement 5 — Fail Fast Option

Add a `--fail-fast` flag that stops testing a source cell the moment its
SSH session cannot be established (bastion unreachable or private host
unreachable). Currently all 7 destination pings are attempted even when
the connection to the private host has already failed, burning up to 140 s
per cell on pointless waits.

---

## Summary

| Improvement | Complexity | Speedup |
|---|---|---|
| 1. Parallel remote pings (bash `&`) | Low — change one line | ~7× per cell |
| 2. Parallel source cells (`ThreadPoolExecutor`) | Medium — refactor main loop | ~8× across cells |
| 3. Per-cell timing | Low — two lines + table column | measurement only |
| 4. RTT capture with parallel pings | Medium — bash tempfile pattern | measurement only |
| 5. Fail-fast flag | Low — check returncode early | avoids wasted time on broken cells |

**Implementing 1 + 2 together takes a ~40 min worst case down to ~30 seconds.**
