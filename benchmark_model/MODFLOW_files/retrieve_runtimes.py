#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
from pathlib import Path
from typing import Optional, Tuple

AGENT_DIR_PATTERN = re.compile(r"^a\d+$")
ELAPSED_PATTERN = re.compile(
    r"Elapsed\s+run\s+time:\s*(\d+)\s*Minutes,\s*([0-9.]+)\s*Seconds",
    re.IGNORECASE,
)
RUN_END_PATTERN = re.compile(
    r"Run\s+end\s+date\s+and\s+time\s*\(yyyy/mm/dd\s+hh:mm:ss\):\s*([0-9/]+\s+[0-9:]+)",
    re.IGNORECASE,
)


def parse_elapsed_minutes(list_file: Path) -> Optional[float]:
    """Parse the elapsed run time from a MODFLOW list file.

    Expected line format:
        Elapsed run time:  6 Minutes, 12.238 Seconds

    Returns runtime in minutes or None if not found.
    """
    try:
        text = list_file.read_text(errors="ignore")
    except OSError:
        return None

    matches = ELAPSED_PATTERN.findall(text)
    if not matches:
        return None

    minutes_str, seconds_str = matches[-1]
    minutes = float(minutes_str)
    seconds = float(seconds_str)
    return minutes + (seconds / 60.0)


def parse_run_end_datetime(list_file: Path) -> Optional[str]:
    """Parse the run end datetime string from a MODFLOW list file."""
    try:
        text = list_file.read_text(errors="ignore")
    except OSError:
        return None

    matches = RUN_END_PATTERN.findall(text)
    if not matches:
        return None

    return matches[-1].strip()


def find_agent_dirs(root: Path) -> list[Path]:
    return sorted(
        [p for p in root.iterdir() if p.is_dir() and AGENT_DIR_PATTERN.match(p.name)],
        key=lambda p: int(p.name[1:]),
    )


def collect_runtimes(root: Path) -> list[Tuple[str, Optional[float], Optional[str]]]:
    runtimes: list[Tuple[str, Optional[float], Optional[str]]] = []
    for agent_dir in find_agent_dirs(root):
        list_file = agent_dir / "output" / "biscayne.list"
        runtime = parse_elapsed_minutes(list_file)
        run_end = parse_run_end_datetime(list_file)
        runtimes.append((agent_dir.name, runtime, run_end))
    return runtimes


def write_csv(
    rows: list[Tuple[str, Optional[float], Optional[str]]],
    output_path: Path,
) -> None:
    with output_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["agent", "runtime_minutes", "run_end_datetime"])
        for agent, runtime, run_end in rows:
            runtime_value = "" if runtime is None else f"{runtime:.6f}"
            writer.writerow([
                agent,
                runtime_value,
                "" if run_end is None else run_end,
            ])


if __name__ == "__main__":
    root_dir = Path(__file__).resolve().parent
    output_csv = root_dir / "agent_runtimes.csv"

    data = collect_runtimes(root_dir)
    print(f"Processing complete: {len(data)} agent runs found.")
    missing = [agent for agent, runtime, _run_end in data if runtime is None]
    if missing:
        print(f"No runtime found for: {', '.join(missing)}")
    available = [(agent, runtime) for agent, runtime, _run_end in data if runtime is not None]
    slowest_agent = None
    slowest_runtime = None
    if available:
        slowest_agent, slowest_runtime = max(available, key=lambda x: x[1])

    data_sorted = sorted(
        data,
        key=lambda x: (float("inf") if x[1] is None else x[1], x[0]),
    )
    write_csv(data_sorted, output_csv)
    print(f"Saved: {output_csv}")
    if slowest_agent is not None and slowest_runtime is not None:
        print(f"Slowest run: {slowest_runtime:.6f} minutes (agent {slowest_agent})")

