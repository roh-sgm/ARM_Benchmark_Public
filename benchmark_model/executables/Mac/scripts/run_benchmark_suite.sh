#!/bin/zsh
#
# run_benchmark_suite.sh
#
# Automated benchmark: runs batches of agents, waits for each batch
# to finish, records the slowest runtime, then moves on to the next.
#
# Usage:
#   ./run_benchmark_suite.sh <executable> [start [end]]
#
#   <executable>  Name (or path) of the MODFLOW binary to benchmark.
#                 Looked up in the parent directory (Mac/) first,
#                 then anywhere on PATH.
#   [start]       First batch to run (default: 1)
#   [end]         Last batch to run  (default: 16)
#
# Examples:
#   ./run_benchmark_suite.sh usgt_180_arm           # ARM binary, all batches
#   ./run_benchmark_suite.sh mfusg_gsi_1_8          # x86 binary, all batches
#   ./run_benchmark_suite.sh usgt_180_arm 5         # ARM binary, batch 5 only
#   ./run_benchmark_suite.sh usgt_180_arm 10 16     # ARM binary, batches 10-16
#   ./run_benchmark_suite.sh mf6 1 8                # MF6 binary, batches 1-8
#
# Results are saved to {ComputerName}_{executable}_{datetime}_benchmark_results.csv
# in this directory.

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON=python3

# Computer name (spaces replaced with underscores) and run timestamp
COMPUTER_NAME=$(scutil --get ComputerName 2>/dev/null | tr ' ' '_' || hostname -s)
RUN_TIMESTAMP=$(date "+%Y-%m-%d_%H%M%S")
# RESULTS_CSV is set after argument parsing so the executable name is available

# ── Parse arguments ────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
    echo "Usage: ./run_benchmark_suite.sh <executable> [start [end]]"
    echo ""
    echo "  <executable>  Binary name to run (e.g. usgt_180_arm, mf6)"
    echo "  [start]       First batch number (default: 1)"
    echo "  [end]         Last batch number  (default: 16)"
    echo ""
    echo "Available binaries in $(cd "${SCRIPT_DIR}/.." && pwd)/:"
    ls -1 "${SCRIPT_DIR}/../" | grep -v '^scripts$' | grep -v '^\.' || echo "  (none found)"
    exit 1
fi

EXECUTABLE="$1"
shift

if [[ $# -eq 0 ]]; then
    BATCH_START=1
    BATCH_END=16
elif [[ $# -eq 1 ]]; then
    BATCH_START=$1
    BATCH_END=$1
else
    BATCH_START=$1
    BATCH_END=$2
fi

RESULTS_CSV="${SCRIPT_DIR}/${COMPUTER_NAME}_${EXECUTABLE}_${RUN_TIMESTAMP}_benchmark_results.csv"

# ── Preflight checks ───────────────────────────────────────────────
RETRIEVE_SCRIPT="${SCRIPT_DIR}/retrieve_runtimes.py"
if [[ ! -f "$RETRIEVE_SCRIPT" ]]; then
    echo "❌  retrieve_runtimes.py not found at: ${RETRIEVE_SCRIPT}"
    echo "    This script must be run from its own directory, or the Python"
    echo "    helper must be present alongside run_benchmark_suite.sh."
    exit 1
fi

# ── Locate executable ──────────────────────────────────────────────
# Looks for the binary in the parent directory (Mac/) first,
# then falls back to anywhere on PATH — no hardcoded paths needed.
if [[ -x "${SCRIPT_DIR}/../${EXECUTABLE}" ]]; then
    EXE_PATH="$(cd "${SCRIPT_DIR}/.." && pwd)/${EXECUTABLE}"
elif command -v "$EXECUTABLE" &>/dev/null; then
    EXE_PATH=$(command -v "$EXECUTABLE")
else
    echo "❌  Cannot find '${EXECUTABLE}'."
    echo "    Place the binary in: $(cd "${SCRIPT_DIR}/.." && pwd)/"
    echo "    or ensure it is on your PATH."
    echo ""
    echo "Available binaries in $(cd "${SCRIPT_DIR}/.." && pwd)/:"
    ls -1 "${SCRIPT_DIR}/../" | grep -v '^scripts$' | grep -v '^\.' || echo "  (none found)"
    exit 1
fi

OS_NAME=$(uname -s)
OS_VERSION=$(sw_vers -productVersion 2>/dev/null || uname -r)
EXE_ARCH=$(file "$EXE_PATH" 2>/dev/null | sed -E 's/.*executable //' | tr -d '\n' || echo "unknown")


# ── Helper: clean output files for agents a1..aN ──────────────────
clean_outputs() {
    local n=$1
    for i in $(seq 1 "$n"); do
        local outdir="${SCRIPT_DIR}/a${i}/output"
        rm -f "${outdir}/biscayne.list" \
              "${outdir}/biscayne.cbc"  \
              "${outdir}/biscayne.hds"
    done
}

# ── Helper: run one batch of N agents ─────────────────────────────
run_batch() {
    local n=$1
    local pids=()

    for i in $(seq 1 "$n"); do
        local agent_dir="${SCRIPT_DIR}/a${i}"
        (
            cd "$agent_dir"
            "$EXE_PATH" biscayne.nam > /dev/null 2>&1
        ) &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
}

# ── Main ──────────────────────────────────────────────────────────

echo "=========================================="
echo "  MODFLOW-USG Benchmark Suite"
echo "  Executable: ${EXECUTABLE} (${EXE_ARCH})"
echo "  Running batches ${BATCH_START} to ${BATCH_END}"
echo "  OS: ${OS_NAME} ${OS_VERSION}"
echo "=========================================="
echo ""

echo "num_agents,slowest_runtime_minutes,slowest_agent,datetime,executable,os,arch" > "$RESULTS_CSV"
echo "  Results file: ${RESULTS_CSV}"
echo ""

for n in $(seq "$BATCH_START" "$BATCH_END"); do
    echo "──────────────────────────────────────────"
    echo "  Batch ${n}/${BATCH_END}: Running ${n} agent(s)..."
    echo "──────────────────────────────────────────"

    clean_outputs "$n"

    start_time=$(date +%s)
    run_batch "$n"
    end_time=$(date +%s)
    wall_seconds=$((end_time - start_time))
    wall_min=$(echo "scale=2; $wall_seconds / 60" | bc)

    output=$("$PYTHON" "$RETRIEVE_SCRIPT" --agents "$n" --workdir "$SCRIPT_DIR" 2>&1)

    slowest_line=$(echo "$output" | grep "^Slowest run:" || true)
    if [[ -n "$slowest_line" ]]; then
        slowest_runtime=$(echo "$slowest_line" | sed -E 's/.*Slowest run: ([0-9.]+) minutes.*/\1/')
        slowest_agent=$(echo "$slowest_line" | sed -E 's/.*\(agent ([^)]+)\).*/\1/')
    else
        slowest_runtime="N/A"
        slowest_agent="N/A"
    fi

    echo "  -> Wall time: ${wall_min} min | Slowest: ${slowest_runtime} min (${slowest_agent})"
    echo ""

    run_datetime=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${n},${slowest_runtime},${slowest_agent},${run_datetime},${EXECUTABLE},${OS_NAME} ${OS_VERSION},${EXE_ARCH}" >> "$RESULTS_CSV"
done

echo ""
echo "=========================================="
echo "  Benchmark Complete!"
echo "=========================================="
echo ""
echo "Results saved to: ${RESULTS_CSV}"
echo ""

printf "%-8s  %-22s  %-8s  %-20s  %-18s  %-16s  %-10s\n" \
    "Agents" "Slowest Runtime (min)" "Agent" "Date/Time" "Executable" "OS" "Arch"
printf "%-8s  %-22s  %-8s  %-20s  %-18s  %-16s  %-10s\n" \
    "------" "---------------------" "-----" "---------" "----------" "--" "----"
while IFS=, read -r num_agents runtime agent dt exe os arch; do
    [[ "$num_agents" == "num_agents" ]] && continue
    printf "%-8s  %-22s  %-8s  %-20s  %-18s  %-16s  %-10s\n" \
        "$num_agents" "$runtime" "$agent" "$dt" "$exe" "$os" "$arch"
done < "$RESULTS_CSV"
