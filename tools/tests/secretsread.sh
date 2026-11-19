#!/bin/sh
# secretsread.sh — helper-binary contract through the compiled binary:
# build, help/usage codes, read-only posture, end-to-end precedence
# (org -> team -> project -> deployment) including cross-org and
# cross-project isolation.
# Builds and seeds under mktemp scratch only; the repo tree is never
# written. Needs the Go toolchain (documented prerequisite).
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
export GOCACHE="$R/.cache/go/build" GOPROXY=off
GOFLAGS="${GOFLAGS:-}${GOFLAGS:+ }-buildvcs=false"; export GOFLAGS
mkdir -p -- "$GOCACHE"

BIN="$F/secretsread"
if ( cd "$R/tools/secretsread" && go build -o "$BIN" . ) 2>"$F/build.log"; then
    ok "builds from repo source"
else
    bad "builds from repo source ($(cat -- "$F/build.log"))"
fi
if [ ! -x "$BIN" ]; then
    printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
    exit 1
fi

runb() { # args... — runs $BIN, sets _out (stdout only) and _rc
    _rc=0
    _out=$("$BIN" "$@" 2>"$F/err.log") || _rc=$?
}

if "$BIN" --help >/dev/null 2>&1; then
    ok "--help exits 0"
else
    bad "--help exits 0"
fi
runb
if [ "$_rc" -eq 2 ] && [ -z "$_out" ]; then
    ok "no args exits 2 with empty stdout"
else
    bad "no args exits 2 with empty stdout (rc=$_rc out='$_out')"
fi
runb --bogus
if [ "$_rc" -eq 2 ]; then
    ok "unknown flag exits 2"
else
    bad "unknown flag exits 2 (rc=$_rc)"
fi
runb --db "$F/s.db" --team shop --name K
if [ "$_rc" -eq 2 ]; then
    ok "missing --org exits 2"
else
    bad "missing --org exits 2 (rc=$_rc)"
fi
runb --db "$F/no-such.db" --org o1 --name K
if [ "$_rc" -eq 1 ] && [ -z "$_out" ]; then
    ok "missing store exits 1 with empty stdout"
else
    bad "missing store exits 1 with empty stdout (rc=$_rc out='$_out')"
fi
: >"$F/empty.db"
runb --db "$F/empty.db" --org o1 --name K
if [ "$_rc" -eq 1 ] && [ -z "$_out" ]; then
    ok "schemaless store exits 1 with empty stdout"
else
    bad "schemaless store exits 1 with empty stdout (rc=$_rc out='$_out')"
fi

if ( cd "$R/tools/secretsread" && go run ./seedtest --db "$F/s.db" \
    --schema "$R/tools/secretsread/secrets/schema.sql" \
    --row 'o1:shop:todo:api-1:LLM_API_KEY:ZGVwbG95' \
    --row 'o1:shop:todo::LLM_API_KEY:cHJvZA==' \
    --row 'o1:shop:::LLM_API_KEY:dGVhbQ==' \
    --row 'o1::::ROOT_CA:cm9vdA==' \
    --row 'o2:shop:todo::LLM_API_KEY:b3RoZXI=' \
    --row 'o1:shop:other::ONLY_P:b25seQ==' ) 2>"$F/seed.log"; then
    ok "fixture seeds"
else
    bad "fixture seeds ($(cat -- "$F/seed.log"))"
fi
runb --db "$F/s.db" --org o1 --team shop --project web --name LLM_API_KEY
if [ "$_rc" -eq 0 ] && [ "$_out" = "dGVhbQ==" ]; then
    ok "team row is the fallback"
else
    bad "team row is the fallback (rc=$_rc out='$_out')"
fi
runb --db "$F/s.db" --org o1 --team shop --project todo --deployment api-1 --name LLM_API_KEY
if [ "$_rc" -eq 0 ] && [ "$_out" = "ZGVwbG95" ]; then
    ok "deployment row wins"
else
    bad "deployment row wins (rc=$_rc out='$_out')"
fi
runb --db "$F/s.db" --org o1 --team shop --project todo --deployment api-9 --name LLM_API_KEY
if [ "$_rc" -eq 0 ] && [ "$_out" = "cHJvZA==" ]; then
    ok "project row is the fallback"
else
    bad "project row is the fallback (rc=$_rc out='$_out')"
fi
runb --db "$F/s.db" --org o1 --team shop --project web --deployment api-1 --name LLM_API_KEY
if [ "$_rc" -eq 0 ] && [ "$_out" = "dGVhbQ==" ]; then
    ok "fallback applies per name"
else
    bad "fallback applies per name (rc=$_rc out='$_out')"
fi
runb --db "$F/s.db" --org o1 --team hr --name ROOT_CA
if [ "$_rc" -eq 0 ] && [ "$_out" = "cm9vdA==" ]; then
    ok "org row is the last fallback"
else
    bad "org row is the last fallback (rc=$_rc out='$_out')"
fi
runb --db "$F/s.db" --org o2 --team shop --project todo --name LLM_API_KEY
if [ "$_rc" -eq 0 ] && [ "$_out" = "b3RoZXI=" ]; then
    ok "same slugs isolated per org"
else
    bad "same slugs isolated per org (rc=$_rc out='$_out')"
fi
runb --db "$F/s.db" --org o1 --team shop --project todo --name ONLY_P
if [ "$_rc" -eq 1 ] && [ -z "$_out" ]; then
    ok "project rows do not leak across projects"
else
    bad "project rows do not leak across projects (rc=$_rc out='$_out')"
fi
runb --db "$F/s.db" --org o1 --team shop --project todo --name MISSING
if [ "$_rc" -eq 1 ] && [ -z "$_out" ]; then
    ok "unknown secret exits 1 with empty stdout"
else
    bad "unknown secret exits 1 with empty stdout (rc=$_rc out='$_out')"
fi
runb --db "$F/s.db" --org o9 --team shop --project todo --name LLM_API_KEY
if [ "$_rc" -eq 1 ] && [ -z "$_out" ]; then
    ok "unknown org exits 1 with empty stdout"
else
    bad "unknown org exits 1 with empty stdout (rc=$_rc out='$_out')"
fi
runb --db "$F/s.db" --org o1 --team shop --deployment api-1 --name LLM_API_KEY
if [ "$_rc" -eq 1 ] && [ -z "$_out" ]; then
    ok "deployment without project exits 1 with empty stdout"
else
    bad "deployment without project exits 1 with empty stdout (rc=$_rc out='$_out')"
fi
runb --db "$F/s.db" --org o1 --project todo --name LLM_API_KEY
if [ "$_rc" -eq 1 ] && [ -z "$_out" ]; then
    ok "project without team exits 1 with empty stdout"
else
    bad "project without team exits 1 with empty stdout (rc=$_rc out='$_out')"
fi

. "$R/tools/lib.sh"
VERB=secretsread
_src=0
_sv=$(secrets_read "$F/s.db" o1 shop todo api-1 LLM_API_KEY) || _src=$?
if [ "$_src" -eq 0 ] && [ "$_sv" = "ZGVwbG95" ]; then
    ok "secrets_read resolves through lib.sh"
else
    bad "secrets_read resolves through lib.sh (rc=$_src out='$_sv')"
fi
_src=0
_sv=$(secrets_read "$F/s.db" o1 shop todo "" NOPE 2>/dev/null) || _src=$?
if [ "$_src" -eq 1 ] && [ -z "$_sv" ]; then
    ok "secrets_read miss exits 1 with empty stdout"
else
    bad "secrets_read miss exits 1 with empty stdout (rc=$_src out='$_sv')"
fi

printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
[ "$fail" -eq 0 ]
