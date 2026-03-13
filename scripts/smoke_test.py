#!/usr/bin/env python3
"""
smoke_test.py — Automated inter-region connectivity smoke tests.

Reads instances.json and verifies that each cell's private host can reach
private hosts in every other cell of the same environment (dev→dev, prod→prod).

Workflow per source cell
------------------------
  1. ProxyJump through the cell's bastion (public IP) using the region/env SSH key.
  2. SSH to the cell's first private host.
  3. From the private host, ping every other same-env cell's first private host.

This mirrors the manual test procedure:
  ssh ubuntu@<bastion> -i ssh-keys/<region>-<env>.pem
  ssh <private-ip>
  ping -c 4 <target-private-ip>

Usage
-----
    python scripts/smoke_test.py [options]

    --instances PATH      Path to instances.json (default: instances.json in repo root)
    --key-dir  DIR        Directory containing SSH private keys (default: ssh-keys/ in repo root)
    --timeout  SECONDS    Per-cell SSH+ping timeout in seconds (default: 180)
    --dry-run             Print what would be tested without running SSH commands
    --debug               Print SSH commands and remote ping commands for each cell
    --regions  r1,r2,...  Only test paths involving these region short-names (e.g. euw2,use1)

instances.json schema (as written by deploy.py --json)
------------------------------------------------------
The file is a JSON object keyed by cell path, e.g.:

    {
      "envs/dev/euw2/cell1000": {
        "bastions": {
          "bastion-euw2-dev-pub-0-cell1000": "35.178.244.94",
          ...
        },
        "private_hosts": {
          "private-euw2-dev-priv-0-cell1000": "10.1.0.148",
          ...
        }
      },
      ...
    }

Key files are expected at: <key-dir>/<region>-<env>.pem
  e.g. ssh-keys/euw2-dev.pem

Exit codes
----------
    0  All tests passed (or --dry-run)
    1  One or more tests failed
    2  Usage or configuration error
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Optional

from rich.console import Console
from rich.table import Table
from rich import box

console = Console()


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------


def load_instances(path: str) -> list[dict]:
    """
    Load instances.json and return a flat list of cell descriptors.

    Each descriptor is a dict with keys:
        cell_path   str  e.g. "envs/dev/euw2/cell1000"
        env         str  e.g. "dev"
        region      str  e.g. "euw2"
        cell        str  e.g. "cell1000"
        bastion_ip  str  public IP of the first bastion in the cell
        private_ip  str  private IP of the first private host in the cell
        key_name    str  key filename stem, e.g. "euw2-dev"

    Cells that lack either bastions or private_hosts are silently skipped.
    """
    instances_path = Path(path)
    if not instances_path.exists():
        raise FileNotFoundError(
            f"instances.json not found at '{path}'. "
            "Run 'python scripts/deploy.py --json' to generate it."
        )

    try:
        raw = json.loads(instances_path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Failed to parse '{path}' as JSON: {exc}") from exc

    if not isinstance(raw, dict):
        raise ValueError(
            f"Expected instances.json to be a JSON object (dict), got {type(raw).__name__}."
        )

    cells: list[dict] = []
    for cell_path, cell_data in raw.items():
        parts = cell_path.strip("/").split("/")
        if len(parts) < 4 or parts[0] != "envs":
            continue

        _, env, region, cell = parts[0], parts[1], parts[2], parts[3]

        if not isinstance(cell_data, dict):
            continue

        bastions: dict = cell_data.get("bastions", {})
        private_hosts: dict = cell_data.get("private_hosts", {})

        if not bastions or not private_hosts:
            continue

        bastion_ip = next(v for _, v in sorted(bastions.items()))
        private_ip = next(v for _, v in sorted(private_hosts.items()))

        cells.append(
            {
                "cell_path": cell_path,
                "env": env,
                "region": region,
                "cell": cell,
                "bastion_ip": bastion_ip,
                "private_ip": private_ip,
                "key_name": f"{region}-{env}",
            }
        )

    return cells


def build_test_groups(
    instances: list[dict],
    regions: Optional[list[str]],
) -> dict[str, list[dict]]:
    """
    Group cells by env. Applies optional region filter.

    Returns {env: [cells]} where each group contains only cells from that env.
    Tests run within each group: every cell pings every other cell in the same group.
    """
    if regions:
        region_set = set(regions)
        instances = [i for i in instances if i["region"] in region_set]

    groups: dict[str, list[dict]] = {}
    for cell in instances:
        groups.setdefault(cell["env"], []).append(cell)

    return groups


# ---------------------------------------------------------------------------
# Test execution
# ---------------------------------------------------------------------------


def run_cell_test(
    src: dict,
    dst_cells: list[dict],
    key_dir: str,
    timeout: int,
    debug: bool = False,
) -> list[dict]:
    """
    Two-hop test: ProxyJump through src bastion → src private host → ping all dst private IPs.

    Uses a single SSH session to run all pings from the private host.
    Parses RESULT:PASS/<FAIL markers from remote stdout.

    Parameters
    ----------
    src:
        Source cell descriptor.
    dst_cells:
        Destination cells to ping from src's private host.
    key_dir:
        Directory containing <region>-<env>.pem key files.
    timeout:
        Seconds before the subprocess is killed (covers the entire SSH session).
    debug:
        If True, print SSH command and remote ping script before running.

    Returns
    -------
    List of result dicts, one per dst cell:
        src       str   "<region>/<cell>"
        dst       str   "<region>/<cell>"
        status    str   "PASS" | "FAIL" | "ERROR"
        output    str   error detail (empty on PASS)
    """
    key_path = Path(key_dir) / f"{src['key_name']}.pem"
    src_label = f"{src['region']}/{src['cell']}"

    # Build remote command: one ping per destination with a result marker
    ping_parts = []
    for dst in dst_cells:
        dst_label = f"{dst['region']}/{dst['cell']}"
        safe_label = dst_label.replace("/", "_")
        ping_parts.append(
            f"( ping -c 4 -W 5 {dst['private_ip']} > /tmp/smoke_{safe_label} 2>&1"
            f"; if grep -q \"bytes from\" /tmp/smoke_{safe_label}; then"
            f" avg=$(grep -E \"rtt|round-trip\" /tmp/smoke_{safe_label} | awk -F'/' '{{print $5}}');"
            f" echo \"RESULT:PASS:{dst_label}:${{avg}} ms\";"
            f" else echo \"RESULT:FAIL:{dst_label}:\"; fi ) &"
        )
    bg_parts = ping_parts
    remote_cmd = " ".join(bg_parts) + " wait"

    # Use ProxyCommand instead of -J so that StrictHostKeyChecking=no and
    # other options are applied to the bastion hop as well.
    proxy_cmd = (
        f"ssh -i {key_path} "
        f"-o StrictHostKeyChecking=no "
        f"-o BatchMode=yes "
        f"-o ConnectTimeout=15 "
        f"-o UserKnownHostsFile=/dev/null "
        f"-o LogLevel=ERROR "
        f"-o IdentitiesOnly=yes "
        f"-W %h:%p ubuntu@{src['bastion_ip']}"
    )
    cmd = [
        "ssh",
        "-i", str(key_path),
        "-o", f"ProxyCommand={proxy_cmd}",
        "-o", "StrictHostKeyChecking=no",
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=15",
        "-o", "UserKnownHostsFile=/dev/null",
        "-o", "LogLevel=ERROR",
        "-o", "IdentitiesOnly=yes",
        f"ubuntu@{src['private_ip']}",
        remote_cmd,
    ]

    if debug:
        print(f"\n    [DEBUG] Step 1 — Bastion:       ubuntu@{src['bastion_ip']}  (key: {key_path})")
        print(f"    [DEBUG] Step 2 — Private host:  ubuntu@{src['private_ip']}")
        print(f"    [DEBUG] Step 3 — Remote pings (parallel):")
        for dst in dst_cells:
            print(f"               ping -c 4 -W 5 {dst['private_ip']}  (parallel) -> {dst['region']}/{dst['cell']}")
        print(f"    [DEBUG] ProxyCommand: {proxy_cmd}")
        print(f"    [DEBUG] Full SSH command: {' '.join(cmd)}")

    # Pre-populate all destinations as ERROR; overwrite on successful parse
    result_map: dict[str, dict] = {
        f"{dst['region']}/{dst['cell']}": {"status": "ERROR", "output": "", "rtt": ""}
        for dst in dst_cells
    }

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        combined = (proc.stdout + proc.stderr).strip()

        # If SSH itself failed (couldn't reach bastion or private host)
        if proc.returncode != 0 and not proc.stdout.strip():
            for data in result_map.values():
                data["output"] = combined
        else:
            # Parse RESULT markers written by the remote ping commands
            for line in proc.stdout.splitlines():
                m = re.match(r"RESULT:(PASS|FAIL):([^:]+):(.*)", line.strip())
                if m:
                    status, dst_label, rtt = m.group(1), m.group(2).strip(), m.group(3).strip()
                    if dst_label in result_map:
                        result_map[dst_label]["status"] = status
                        result_map[dst_label]["rtt"] = rtt

            # Any destination still ERROR means its marker was never printed
            # (SSH to private host likely failed)
            if proc.returncode != 0:
                for data in result_map.values():
                    if data["status"] == "ERROR" and not data["output"]:
                        data["output"] = combined

    except subprocess.TimeoutExpired:
        for data in result_map.values():
            data["status"] = "ERROR"
            data["output"] = f"Timed out after {timeout}s"
    except FileNotFoundError:
        for data in result_map.values():
            data["status"] = "ERROR"
            data["output"] = "ssh binary not found — is OpenSSH installed?"
    except OSError as exc:
        for data in result_map.values():
            data["status"] = "ERROR"
            data["output"] = f"OS error: {exc}"

    return [
        {
            "src": src_label,
            "dst": dst_label,
            "status": data["status"],
            "output": data["output"],
            "rtt": data["rtt"],
        }
        for dst_label, data in result_map.items()
    ]


# ---------------------------------------------------------------------------
# Result rendering
# ---------------------------------------------------------------------------

_STATUS_STYLE = {
    "PASS": "bold green",
    "FAIL": "bold red",
    "ERROR": "bold yellow",
    "DRY-RUN": "dim",
    "SKIPPED": "dim",
}


def render_results(results: list[dict]) -> None:
    """Print a rich summary table of smoke-test results."""
    if not results:
        console.print("No tests to display.")
        return

    total = len(results)
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")
    errors = sum(1 for r in results if r["status"] == "ERROR")
    skipped = sum(1 for r in results if r["status"] == "SKIPPED")

    table = Table(
        title="Smoke Test Results",
        box=box.ROUNDED,
        show_lines=True,
        header_style="bold cyan",
    )
    table.add_column("ENV", style="dim", no_wrap=True)
    table.add_column("Source (region/cell)", no_wrap=True)
    table.add_column("Destination (region/cell)", no_wrap=True)
    table.add_column("Status", justify="center", no_wrap=True)
    table.add_column("Latency", justify="right", no_wrap=True)
    table.add_column("Detail", overflow="fold")
    table.add_column("Duration", justify="right", no_wrap=True)

    prev_src = None
    for r in results:
        src = r["src"]
        env = r.get("env", "")
        status = r["status"]
        style = _STATUS_STYLE.get(status, "")
        detail = r.get("output", "") if status != "PASS" else ""
        latency = r.get("rtt", "")
        duration = f"{r['duration']:.1f}s" if "duration" in r else ""

        # Only print src label on its first row to reduce visual noise
        src_display = src if src != prev_src else ""
        env_display = env if src != prev_src else ""
        prev_src = src

        table.add_row(
            env_display,
            src_display,
            r["dst"],
            f"[{style}]{status}[/{style}]",
            latency,
            f"[dim]{detail}[/dim]" if detail else "",
            duration,
        )

    console.print()
    console.print(table)
    console.print(
        f"  Total: [bold]{total}[/bold]"
        f"  Passed: [bold green]{passed}[/bold green]"
        f"  Failed: [bold red]{failed}[/bold red]"
        f"  Errors: [bold yellow]{errors}[/bold yellow]"
        f"  Skipped: [dim]{skipped}[/dim]"
    )


# ---------------------------------------------------------------------------
# CLI entrypoint
# ---------------------------------------------------------------------------

_REPO_ROOT = Path(__file__).resolve().parent.parent


def _parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="smoke_test.py",
        description=(
            "Automated inter-region connectivity smoke tests. "
            "ProxyJumps through each bastion to its private host, "
            "then pings all same-env private hosts in other cells."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python scripts/smoke_test.py\n"
            "  python scripts/smoke_test.py --debug --regions euw1,euw2\n"
            "  python scripts/smoke_test.py --dry-run\n"
            "  python scripts/smoke_test.py --timeout 300"
        ),
    )
    parser.add_argument(
        "--instances",
        default=str(_REPO_ROOT / "instances.json"),
        metavar="PATH",
        help="Path to instances.json (default: instances.json in repo root)",
    )
    parser.add_argument(
        "--key-dir",
        default=str(_REPO_ROOT / "ssh-keys"),
        metavar="DIR",
        help="Directory containing SSH private key files (default: ssh-keys/ in repo root)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=180,
        metavar="SECONDS",
        help="Per-cell SSH+ping timeout in seconds (default: 180)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be tested without running SSH commands",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Print SSH commands and remote ping commands for each cell",
    )
    parser.add_argument(
        "--regions",
        default=None,
        metavar="r1,r2,...",
        help="Comma-separated region short-names to filter tests (e.g. euw2,use1)",
    )
    parser.add_argument(
        "--fail-fast",
        action="store_true",
        help="Stop all remaining tests as soon as the first failure or error is detected",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = _parse_args(argv)

    regions: Optional[list[str]] = None
    if args.regions:
        regions = [r.strip() for r in args.regions.split(",") if r.strip()]

    try:
        instances = load_instances(args.instances)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    if not instances:
        print("ERROR: No usable cells found in instances.json.", file=sys.stderr)
        return 2

    groups = build_test_groups(instances, regions)
    if not groups:
        print("No cells found matching the region filter.", file=sys.stderr)
        return 2

    total_pairs = sum(len(cells) * (len(cells) - 1) for cells in groups.values())
    print(f"Found {len(instances)} cell(s) across {len(groups)} env(s). "
          f"Running {total_pairs} same-env connectivity test(s).")

    if args.dry_run:
        print("DRY-RUN mode — SSH commands will not be executed.\n")

    key_dir_path = Path(args.key_dir)
    if not key_dir_path.is_dir():
        print(
            f"WARNING: key-dir '{args.key_dir}' does not exist. "
            "SSH tests will fail unless keys are found elsewhere.",
            file=sys.stderr,
        )

    all_results: list[dict] = []
    results_lock = threading.Lock()
    print_lock = threading.Lock()
    stop_event = threading.Event()

    for env, cells in sorted(groups.items()):
        print(f"\n[{env.upper()}] {len(cells)} cell(s)")

        if args.dry_run:
            for src in cells:
                dst_cells = [c for c in cells if c["cell_path"] != src["cell_path"]]
                src_label = f"{src['region']}/{src['cell']}"
                print(f"  {src_label}  (bastion: {src['bastion_ip']}, private: {src['private_ip']})")
                for dst in dst_cells:
                    dst_label = f"{dst['region']}/{dst['cell']}"
                    print(f"    -> {dst_label} ({dst['private_ip']})")
                    all_results.append({
                        "env": env,
                        "src": src_label,
                        "dst": dst_label,
                        "status": "DRY-RUN",
                        "output": "",
                    })
            continue

        def test_and_print(src: dict, dst_cells: list[dict], env: str = env) -> list[dict]:
            src_label = f"{src['region']}/{src['cell']}"

            if stop_event.is_set():
                skipped_results = [
                    {
                        "src": src_label,
                        "dst": f"{dst['region']}/{dst['cell']}",
                        "status": "SKIPPED",
                        "output": "",
                        "env": env,
                        "duration": 0.0,
                    }
                    for dst in dst_cells
                ]
                lines = [f"  {src_label}  (bastion: {src['bastion_ip']}, private: {src['private_ip']})"]
                for r in skipped_results:
                    lines.append(f"    -> {r['dst']} ... {r['status']}")
                with print_lock:
                    print("\n".join(lines))
                return skipped_results

            start = time.perf_counter()
            results = run_cell_test(src, dst_cells, args.key_dir, args.timeout, debug=args.debug)
            elapsed = round(time.perf_counter() - start, 1)

            lines = [f"  {src_label}  (bastion: {src['bastion_ip']}, private: {src['private_ip']})"]
            for r in results:
                r["env"] = env
                r["duration"] = elapsed
                lines.append(f"    -> {r['dst']} ... {r['status']}")
                if r["status"] != "PASS" and r["output"]:
                    for line in r["output"].splitlines():
                        lines.append(f"       | {line}")
                if args.fail_fast and r["status"] in ("FAIL", "ERROR"):
                    stop_event.set()
            with print_lock:
                print("\n".join(lines))
            return results

        futures = {}
        with ThreadPoolExecutor(max_workers=16) as executor:
            for src in cells:
                dst_cells = [c for c in cells if c["cell_path"] != src["cell_path"]]
                future = executor.submit(test_and_print, src, dst_cells)
                futures[future] = src

            for future in as_completed(futures):
                cell_results = future.result()
                with results_lock:
                    all_results.extend(cell_results)

    render_results(all_results)

    if args.dry_run:
        return 0

    return 1 if any(r["status"] not in ("PASS",) for r in all_results if r["status"] != "SKIPPED") else 0


if __name__ == "__main__":
    sys.exit(main())
