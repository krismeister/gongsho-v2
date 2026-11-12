#!/bin/sh
# Probe3: yq-free lib.sh paths (env ensure, live stop, dead-socket get).
set -eu
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
export VERB=probe3 GONGSHO_REPO=$R
. "$GONGSHO_REPO/tools/lib.sh"
pass=0; fail=0
ok() { pass=$((pass+1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1"; }
expect_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi
}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
cp "$R/templates/goa-api/app/.example.env" "$T/.example.env"
unset LOG_LEVEL
source_app_env "$T"
expect_eq "env ensure creates .env" "$(test -f "$T/.env" && echo yes)" "yes"
expect_eq "env sources tunable" "${LOG_LEVEL:-unset}" "info"
printf 'LOG_LEVEL=debug\n' >"$T/.env"
unset LOG_LEVEL
source_app_env "$T"
expect_eq "env keeps existing .env" "${LOG_LEVEL:-unset}" "debug"
sleep 30 & _sp=$!
printf '%s' "$_sp" >"$T/live.pid"
if (stop_pidfile "$T/live.pid" 3 >/dev/null 2>&1); then ok "stop live pid"; else bad "stop live pid"; fi
pid_is_live "$_sp" && { bad "victim still alive"; kill -KILL "$_sp" 2>/dev/null || true; } || ok "victim reaped"
[ -f "$T/live.pid" ] && bad "pidfile not removed" || ok "pidfile removed"
expect_eq "direct_get dead socket" "$(direct_get "$T/dead.sock" /healthz "$T/out")" "000"
rm -rf "$T"
# NOTE (landing): the original `printf '---...'` passes the leading dashes
# as printf options under bash-as-sh and aborts; sibling `%s` form instead.
printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
[ "$fail" -eq 0 ]
