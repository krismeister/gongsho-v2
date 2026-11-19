#!/bin/sh
# secrets-setup.sh — machine provisioning hermetic: .env creation,
# master-key ensure, idempotence, refusal to overwrite, usage codes.
# Runs the real tools/setup against a fake GONGSHO_REPO; the repo tree
# is never written. Needs Go, yq, and Caddy (documented prerequisites).
set -eu
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
pass=0; fail=0
ok() { pass=$((pass+1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1"; }

for _c in go yq caddy; do
    if ! command -v "$_c" >/dev/null 2>&1; then
        bad "prerequisite $_c present"
    fi
done
if [ "$fail" -ne 0 ]; then
    printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
    exit 1
fi

G="$F/root"
mkdir -p -- "$G" "$G/tools"
cp -- "$R/.example.env" "$G/.example.env"
cp -- "$R/tools/lib.sh" "$G/tools/lib.sh"

runv() { # args... — runs setup against the fake root, sets _out and _rc
    _rc=0
    _out=$(GONGSHO_REPO="$G" GONGSHO_HOME="$F/home" sh "$R/tools/setup" "$@" 2>&1) || _rc=$?
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
if [ "$_rc" -eq 0 ] && [ -f "$G/.env" ]; then
    ok "first run exits 0 and creates .env"
else
    bad "first run exits 0 and creates .env (rc=$_rc)"
fi
_k1=$(grep '^GONGSHO_SECRETS_MASTER_KEY=' "$G/.env" | cut -d= -f2-)
if [ -n "$_k1" ] && [ "$(printf '%s' "$_k1" | base64 -d 2>/dev/null | wc -c | tr -d ' ')" = "32" ]; then
    ok "generated key decodes to 32 bytes"
else
    bad "generated key decodes to 32 bytes"
fi
case "$_out" in
    *fingerprint*) ok "fingerprint logged, key never printed" ;;
    *) bad "fingerprint logged, key never printed" ;;
esac
case "$_out" in
    *"$_k1"*) bad "key material absent from logs" ;;
    *) ok "key material absent from logs" ;;
esac

runv
_k2=$(grep '^GONGSHO_SECRETS_MASTER_KEY=' "$G/.env" | cut -d= -f2-)
if [ "$_rc" -eq 0 ] && [ "$_k2" = "$_k1" ] && [ "$(grep -c '^GONGSHO_SECRETS_MASTER_KEY=' "$G/.env")" = "1" ]; then
    ok "rerun is idempotent (key unchanged, single line)"
else
    bad "rerun is idempotent (rc=$_rc)"
fi

cp -- "$G/.env" "$F/before.env"
printf '%s\n' "GONGSHO_SECRETS_MASTER_KEY=not-valid!!" >>"$G/.env"
runv
if [ "$_rc" -eq 1 ]; then
    ok "malformed key exits 1"
else
    bad "malformed key exits 1 (rc=$_rc)"
fi
printf '%s\n' "GONGSHO_SECRETS_MASTER_KEY=AAAA" >"$G/.env"
cp -- "$G/.env" "$F/after.env"
runv
if [ "$_rc" -eq 1 ] && cmp -s "$G/.env" "$F/after.env"; then
    ok "malformed key refuses to overwrite"
else
    bad "malformed key refuses to overwrite (rc=$_rc)"
fi

printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
[ "$fail" -eq 0 ]
