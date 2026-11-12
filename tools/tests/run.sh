#!/bin/sh
# run.sh — execute every tools/tests suite with a combined summary.
# Exits 0 only when every suite passes. Runnable from anywhere:
#   sh tools/tests/run.sh
set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RUN_TMP=$(mktemp -d)
trap 'rm -rf "$RUN_TMP"' EXIT

SUITES="lib-smoke.sh lib-probe.sh lib-probe2.sh lib-probe3.sh lib-probe4.sh"
n_suites=0
total_pass=0
total_fail=0
failed=""

for s in $SUITES; do
    n_suites=$((n_suites + 1))
    printf '=== %s ===\n' "$s"
    if sh "$TEST_DIR/$s" >"$RUN_TMP/out.log" 2>&1; then
        rc=0
    else
        rc=$?
    fi
    cat "$RUN_TMP/out.log"
    line=$(grep -E '^pass=[0-9]+ fail=[0-9]+$' "$RUN_TMP/out.log" | tail -1 || true)
    if [ -z "$line" ]; then
        printf '%s\n' "--- $s: NO SUMMARY LINE (suite broken, exit $rc)"
        failed="$failed $s"
        total_fail=$((total_fail + 1))
    else
        p=${line#pass=}; p=${p%% fail=*}
        f=${line##* fail=}
        total_pass=$((total_pass + p))
        total_fail=$((total_fail + f))
        if [ "$rc" -ne 0 ] || [ "$f" -ne 0 ]; then
            failed="$failed $s"
        fi
        printf '%s\n' "--- $s: pass=$p fail=$f (exit $rc)"
    fi
done

printf '\n suites=%d total_pass=%d total_fail=%d\n' "$n_suites" "$total_pass" "$total_fail"
if [ -z "$failed" ]; then
    printf 'ALL GREEN\n'
    exit 0
fi
printf 'FAILED SUITES:%s\n' "$failed"
exit 1
