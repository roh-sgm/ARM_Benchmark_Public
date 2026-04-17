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
# Results are saved/appended to benchmark_results.csv in this directory.

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_CSV="${SCRIPT_DIR}/benchmark_results.csv"
PYTHON=python3

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

# ── Helper: read already-completed batches from CSV ───────────────
get_existing_batches() {
    if [[ ! -f "$RESULTS_CSV" ]]; then
        return
    fi
    tail -n +2 "$RESULTS_CSV" | cut -d',' -f1 | sort -n
}

# ── Check for duplicates and warn ─────────────────────────────────
check_duplicates() {
    local existing
    existing=($(get_existing_batches))
    if [[ ${#existing[@]} -eq 0 ]]; then
        return 0
    fi

    echo "  Existing results in CSV: batches ${existing[*]}"
    echo ""

    local duplicates=()
    for n in $(seq "$BATCH_START" "$BATCH_END"); do
        for e in "${existing[@]}"; do
            if [[ "$n" -eq "$e" ]]; then
                duplicates+=("$n")
                break
            fi
        done
    done

    if [[ ${#duplicates[@]} -gt 0 ]]; then
        echo "  ⚠️  WARNING: Batches already have results: ${duplicates[*]}"
        echo "     Re-running will add DUPLICATE rows to the CSV."
        echo ""
        printf "  Continue anyway? [y/N] "
        read -r confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "  Aborted."
            exit 0
        fi
        echo ""
    fi
}

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

if [[ ! -f "$RESULTS_CSV" ]]; then
    echo "num_agents,slowest_runtime_minutes,slowest_agent,datetime,executable,os,arch" > "$RESULTS_CSV"
    echo "  Created new results file: ${RESULTS_CSV}"
else
    local_count=$(( $(wc -l < "$RESULTS_CSV") - 1 ))
    echo "  Appending to existing results file (${local_count} batches already recorded)"
fi
echo ""

check_duplicates

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

    output=$("$PYTHON" "${SCRIPT_DIR}/retrieve_runtimes.py" --agents "$n" 2>&1)

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
