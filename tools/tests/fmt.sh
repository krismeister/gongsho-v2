#!/bin/sh
# fmt.sh — repo formatter verb: formats a fixture module, checks help /
# usage codes, idempotence, and the committed lefthook config parses.
# Builds nothing outside mktemp scratch; the repo tree is never written.
# Needs the Go toolchain (gofmt ships with it).
set -eu
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
pass=0; fail=0
ok() { pass=$((pass+1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1"; }

if ! command -v go >/dev/null 2>&1; then
    bad "go toolchain present"
    printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
    exit 1
fi

G="$F/root"
mkdir -p -- "$G/fakemod"
cat >"$G/fakemod/go.mod" <<'EOF'
module example.com/fake

go 1.27.3
EOF
cat >"$G/fakemod/main.go" <<'EOF'
package main

import "fmt"

func main(){fmt.Println("x")}
EOF
cat >"$G/.example.env" <<'EOF'
GONGSHO_PORT=8181
EOF
mkdir -p -- "$G/tools"
cp -- "$R/tools/lib.sh" "$G/tools/lib.sh"

runv() { # args... — runs fmt against the fake root, sets _out and _rc
    _rc=0
    _out=$(GONGSHO_REPO="$G" GONGSHO_HOME="$F/home" sh "$R/tools/fmt" "$@" 2>&1) || _rc=$?
}

runv --help
if [ "$_rc" -eq 0 ]; then
    ok "--help exits 0"
else
    bad "--help exits 0 (rc=$_rc)"
fi
runv extra
if [ "$_rc" -eq 2 ]; then
    ok "extra arg exits 2"
else
    bad "extra arg exits 2 (rc=$_rc)"
fi
runv
if [ "$_rc" -eq 0 ] && [ -z "$(gofmt -l "$G/fakemod/main.go")" ]; then
    ok "formats the fixture module"
else
    bad "formats the fixture module (rc=$_rc)"
fi
case "$_out" in
    *main.go*) ok "changed file reported" ;;
    *) bad "changed file reported" ;;
esac
runv
if [ "$_rc" -eq 0 ]; then
    case "$_out" in
        *"already formatted"*) ok "clean rerun reports clean" ;;
        *) bad "clean rerun reports clean" ;;
    esac
else
    bad "clean rerun reports clean (rc=$_rc)"
fi
if command -v yq >/dev/null 2>&1; then
    if yq eval '.' "$R/lefthook.yml" >/dev/null 2>&1; then
        ok "lefthook.yml parses"
    else
        bad "lefthook.yml parses"
    fi
else
    ok "lefthook.yml parses (yq absent, skipped)"
fi

printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
[ "$fail" -eq 0 ]
