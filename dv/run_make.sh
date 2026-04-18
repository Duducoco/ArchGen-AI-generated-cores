#!/usr/bin/env bash
# Run random verification for every test in testlist.yaml against the 5pipe-stall core.
# Runs up to half the system CPU cores in parallel; each run collects coverage.
# Usage: ./run_make.sh [TEST_NUM]
#   TEST_NUM: number of random-seed runs per test (default: 3)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTLIST="$SCRIPT_DIR/target/archgen_rv32i/testlist.yaml"
# CORE="5pipe-stall"
CORE="single"
# Map CORE → make target
case "$CORE" in
    single)     MAKE_TARGET="run_single" ;;
    5pipe-stall) MAKE_TARGET="run_5pipe" ;;
    *) echo "ERROR: unknown CORE '$CORE'"; exit 1 ;;
esac
TEST_NUM="${1:-50}"

MAX_JOBS=$(( $(nproc) / 2 ))
(( MAX_JOBS < 1 )) && MAX_JOBS=1

RESULT_DIR=$(mktemp -d)
trap 'rm -rf "$RESULT_DIR"' EXIT

mapfile -t TESTS < <(grep '^- test:' "$TESTLIST" | awk '{print $3}' | tr -d '\r')
[[ ${#TESTS[@]} -eq 0 ]] && { echo "ERROR: No tests found in $TESTLIST"; exit 1; }

total=$(( ${#TESTS[@]} * TEST_NUM ))

echo "============================================================"
echo " ArchGen $CORE random verification"
echo " Tests: ${#TESTS[@]}, Runs/test: $TEST_NUM, Total: $total"
echo " Core: $CORE,  Parallel jobs: $MAX_JOBS / $(nproc) CPUs"
echo "============================================================"

run_one() {
    local test="$1" seed="$2"

    make -C "$SCRIPT_DIR" "$MAKE_TARGET" TEST="$test" SEED="$seed" COV=1 \
        > "$RESULT_DIR/${test}__${seed}.log" 2>&1
    local rc=$?

    local compare_log="$SCRIPT_DIR/out/$CORE/${test}_seed${seed}/compare.log"
    local status
    if (( rc != 0 )); then
        status="ERROR(make)"
    elif grep -q "PASSED" "$compare_log" 2>/dev/null; then
        status="PASS"
    else
        status="FAIL"
    fi

    echo "$status" > "$RESULT_DIR/${test}__${seed}.result"
    echo "[$status] $test  seed=$seed"
}

# Dispatch with a parallel job pool
declare -a pids=()

for test in "${TESTS[@]}"; do
    for ((i = 0; i < TEST_NUM; i++)); do
        seed=$RANDOM

        # Throttle: wait for a slot to open
        while (( ${#pids[@]} >= MAX_JOBS )); do
            wait -n 2>/dev/null || true
            new_pids=()
            for pid in "${pids[@]}"; do
                kill -0 "$pid" 2>/dev/null && new_pids+=("$pid")
            done
            pids=("${new_pids[@]}")
        done

        echo "  --> launching $test  seed=$seed"
        run_one "$test" "$seed" &
        pids+=($!)
    done
done

wait  # drain remaining jobs

# Collect and print results
echo ""
echo "============================================================"
echo " RESULTS:"
pass=0; fail=0
declare -a results=()
for f in "$RESULT_DIR"/*.result; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f" .result)
    test="${base%__*}"
    seed="${base##*__}"
    status=$(<"$f")
    results+=("[$status] $test  seed=$seed")
    [[ $status == "PASS" ]] && (( pass++ )) || (( fail++ ))
done

printf '%s\n' "${results[@]}" | sort | sed 's/^/  /'

echo ""
echo " SUMMARY: $pass/$total PASSED,  $fail FAILED"
echo "============================================================"

(( fail == 0 ))
