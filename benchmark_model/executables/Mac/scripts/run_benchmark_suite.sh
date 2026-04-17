#!/bin/zsh
#
# run_benchmark_suite.sh
#
# Automated benchmark: runs batches of agents, waits for each batch
# to finish, records the slowest runtime, then moves on to the next.
#
# Usage:
#   ./run_benchmark_suite.sh              # run batches 1 through 16
#   ./run_benchmark_suite.sh 5            # run only batch 5
#   ./run_benchmark_suite.sh 10 16        # run batches 10 through 16
#
# Results are saved/appended to benchmark_results.csv in this directory.

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_CSV="${SCRIPT_DIR}/benchmark_results.csv"
PYTHON=python3

# Parse arguments: START and END batch
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
EXECUTABLE="mfusgt_180_arm"
if [[ -x "${SCRIPT_DIR}/../${EXECUTABLE}" ]]; then
    EXE_PATH="$(cd "${SCRIPT_DIR}/.." && pwd)/${EXECUTABLE}"
elif command -v "$EXECUTABLE" &>/dev/null; then
    EXE_PATH=$(command -v "$EXECUTABLE")
else
    echo "❌  Cannot find '${EXECUTABLE}'."
    echo "    Place the binary in: $(cd "${SCRIPT_DIR}/.." && pwd)/"
    echo "    or ensure it is on your PATH."
    exit 1
fi
OS_NAME=$(uname -s)                          # e.g. Darwin, Linux
OS_VERSION=$(sw_vers -productVersion 2>/dev/null || uname -r)  # e.g. 15.3.1
EXE_ARCH=$(file "$EXE_PATH" 2>/dev/null | sed -E 's/.*executable //' | tr -d '\n' || echo "unknown")

# ── Helper: read already-completed batches from CSV ───────────────
get_existing_batches() {
    if [[ ! -f "$RESULTS_CSV" ]]; then
        return
    fi
    # Return sorted list of batch numbers already in the CSV
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

    # Find which requested batches already have results
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

# ── Helper: run one batch of N agents and return slowest runtime ──
run_batch() {
    local n=$1
    local pids=()

    # Launch agents a1..aN in background
    for i in $(seq 1 "$n"); do
        local agent_dir="${SCRIPT_DIR}/a${i}"
        (
            cd "$agent_dir"
            "$EXE_PATH" biscayne.nam > /dev/null 2>&1
        ) &
        pids+=($!)
    done

    # Wait for all agents to finish
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
}

# ── Main ──────────────────────────────────────────────────────────

echo "=========================================="
echo "  MODFLOW-USG Benchmark Suite"
echo "  Running batches ${BATCH_START} to ${BATCH_END}"
echo "  Executable: ${EXECUTABLE} (${EXE_ARCH})"
echo "  OS: ${OS_NAME} ${OS_VERSION}"
echo "=========================================="
echo ""

# Write CSV header only if file doesn't exist
if [[ ! -f "$RESULTS_CSV" ]]; then
    echo "num_agents,slowest_runtime_minutes,slowest_agent,datetime,executable,os,arch" > "$RESULTS_CSV"
    echo "  Created new results file: ${RESULTS_CSV}"
else
    local_count=$(( $(wc -l < "$RESULTS_CSV") - 1 ))
    echo "  Appending to existing results file (${local_count} batches already recorded)"
fi
echo ""

# Check for duplicate batches and warn
check_duplicates

for n in $(seq "$BATCH_START" "$BATCH_END"); do
    echo "──────────────────────────────────────────"
    echo "  Batch ${n}/${BATCH_END}: Running ${n} agent(s)..."
    echo "──────────────────────────────────────────"

    # 1. Clean previous output
    clean_outputs "$n"

    # 2. Run agents and wait
    start_time=$(date +%s)
    run_batch "$n"
    end_time=$(date +%s)
    wall_seconds=$((end_time - start_time))
    wall_min=$(echo "scale=2; $wall_seconds / 60" | bc)

    # 3. Parse runtimes using retrieve_runtimes.py
    output=$("$PYTHON" "${SCRIPT_DIR}/retrieve_runtimes.py" --agents "$n" 2>&1)

    # Extract slowest agent and runtime from the script output
    slowest_line=$(echo "$output" | grep "^Slowest run:" || true)
    if [[ -n "$slowest_line" ]]; then
        # Format: "Slowest run: 5.381167 minutes (agent a5)"
        slowest_runtime=$(echo "$slowest_line" | sed -E 's/.*Slowest run: ([0-9.]+) minutes.*/\1/')
        slowest_agent=$(echo "$slowest_line" | sed -E 's/.*\(agent ([^)]+)\).*/\1/')
    else
        slowest_runtime="N/A"
        slowest_agent="N/A"
    fi

    # 4. Log result
    echo "  -> Wall time: ${wall_min} min | Slowest: ${slowest_runtime} min (${slowest_agent})"
    echo ""

    # 5. Append to CSV
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

# Print summary table
printf "%-8s  %-22s  %-8s  %-20s  %-18s  %-16s  %-10s\n" \
    "Agents" "Slowest Runtime (min)" "Agent" "Date/Time" "Executable" "OS" "Arch"
printf "%-8s  %-22s  %-8s  %-20s  %-18s  %-16s  %-10s\n" \
    "------" "---------------------" "-----" "---------" "----------" "--" "----"
while IFS=, read -r num_agents runtime agent dt exe os arch; do
    [[ "$num_agents" == "num_agents" ]] && continue  # skip header
    printf "%-8s  %-22s  %-8s  %-20s  %-18s  %-16s  %-10s\n" \
        "$num_agents" "$runtime" "$agent" "$dt" "$exe" "$os" "$arch"
done < "$RESULTS_CSV"
