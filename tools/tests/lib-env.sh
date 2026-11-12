#!/bin/sh
# lib-env.sh — machine-config sourcing: root .env overrides, built-in
# defaults, Go cache fallback, GOFLAGS handling.
set -eu
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
export VERB=libenv
F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/tools"
cp "$R/tools/lib.sh" "$F/tools/lib.sh"

pass=0; fail=0
ok() { pass=$((pass+1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1"; }

_clear='unset GONGSHO_SCHEME GONGSHO_HOST GONGSHO_PORT GONGSHO_START_HEALTH_TIMEOUT GONGSHO_STOP_GRACE GONGSHO_MIGRATE_VERSION GOCACHE GOMODCACHE GOPATH GOFLAGS'

# --- defaults: fake root without .env, ambient vars cleared ---
if _def=$(eval "$_clear"; GONGSHO_REPO="$F" VERB=t; . "$R/tools/lib.sh" >/dev/null 2>&1; printf '%s|%s|%s|%s' "$CADDY_ORIGIN" "$START_HEALTH_TIMEOUT" "$STOP_GRACE" "$MIGRATE_VERSION"); then
    if [ "$_def" = "http://localhost:8181|10|5|v4.20.1" ]; then
        ok "defaults without .env"
    else
        bad "defaults without .env (got '$_def')"
    fi
else
    bad "defaults without .env (source failed)"
fi

# --- override: fake-root .env setting all six vars ---
cat >"$F/.env" <<'EOF'
GONGSHO_SCHEME=https
GONGSHO_HOST=example.test
GONGSHO_PORT=9999
GONGSHO_START_HEALTH_TIMEOUT=11
GONGSHO_STOP_GRACE=6
GONGSHO_MIGRATE_VERSION=v9.9.9
EOF
if _ovr=$(eval "$_clear"; GONGSHO_REPO="$F" VERB=t; . "$R/tools/lib.sh" >/dev/null 2>&1; printf '%s|%s|%s|%s' "$CADDY_ORIGIN" "$START_HEALTH_TIMEOUT" "$STOP_GRACE" "$MIGRATE_VERSION"); then
    if [ "$_ovr" = "https://example.test:9999|11|6|v9.9.9" ]; then
        ok "fake-root .env overrides all six"
    else
        bad "fake-root .env overrides all six (got '$_ovr')"
    fi
else
    bad "fake-root .env overrides all six (source failed)"
fi

# --- partial .env: set vars win, the rest default ---
printf 'GONGSHO_PORT=7777\n' >"$F/.env"
if _part=$(eval "$_clear"; GONGSHO_REPO="$F" VERB=t; . "$R/tools/lib.sh" >/dev/null 2>&1; printf '%s|%s|%s|%s' "$CADDY_ORIGIN" "$START_HEALTH_TIMEOUT" "$STOP_GRACE" "$MIGRATE_VERSION"); then
    if [ "$_part" = "http://localhost:7777|10|5|v4.20.1" ]; then
        ok "partial .env mixes file and defaults"
    else
        bad "partial .env mixes file and defaults (got '$_part')"
    fi
else
    bad "partial .env mixes file and defaults (source failed)"
fi

# --- missing file: silent success ---
rm -f "$F/.env"
_errf="$F/stderr.txt"
if _sil=$(eval "$_clear"; GONGSHO_REPO="$F" VERB=t; . "$R/tools/lib.sh" >/dev/null 2>"$_errf"; printf '%s' "$CADDY_ORIGIN"); then
    if [ ! -s "$_errf" ] && [ "$_sil" = "http://localhost:8181" ]; then
        ok "missing .env silent with defaults"
    else
        bad "missing .env silent with defaults (stderr bytes: $(wc -c <"$_errf"), origin: '$_sil')"
    fi
else
    bad "missing .env silent with defaults (source failed)"
fi

# --- go caches: nested fake root keeps these cases isolated ---
_G="$F/gocase"
mkdir -p "$_G/tools"
cp "$R/tools/lib.sh" "$_G/tools/lib.sh"

# --- preset caches respected (go never consulted) ---
if _pre=$(eval "$_clear"; GONGSHO_REPO="$_G" VERB=t; GOCACHE=/keep/gocache GOMODCACHE=/keep/modcache; . "$R/tools/lib.sh" >/dev/null 2>&1; printf '%s|%s' "$GOCACHE" "$GOMODCACHE"); then
    if [ "$_pre" = "/keep/gocache|/keep/modcache" ] && [ ! -e "$_G/.cache" ]; then
        ok "preset go caches respected"
    else
        bad "preset go caches respected (got '$_pre')"
    fi
else
    bad "preset go caches respected (source failed)"
fi

# --- missing go silent ---
mkdir -p "$_G/nogobin"
ln -s "$(command -v dirname)" "$_G/nogobin/dirname"
if _mgo=$(eval "$_clear"; GONGSHO_REPO="$_G" VERB=t PATH="$_G/nogobin"; . "$R/tools/lib.sh" 2>"$_G/mgo.err"; printf 'VARS:%s|%s' "${GOCACHE:-UNSET}" "${GOMODCACHE:-UNSET}"); then
    if [ "$_mgo" = "VARS:UNSET|UNSET" ] && [ ! -s "$_G/mgo.err" ] && [ ! -e "$_G/.cache" ]; then
        ok "missing go silent"
    else
        bad "missing go silent (got '$_mgo')"
    fi
else
    bad "missing go silent (source failed)"
fi

# --- unwritable default falls back (stub go printing a bad dir) ---
mkdir -p "$_G/stubbin"
printf '#!/bin/sh\nif [ "$1 $2" = "env GOCACHE" ]; then echo "${GO_STUB_CACHE:?stub needs GO_STUB_CACHE}"; else echo "stub-go: wrong call $*" >&2; exit 1; fi\n' >"$_G/stubbin/go"
chmod +x "$_G/stubbin/go"
export GO_STUB_CACHE="$_G/nope/gocache"
if _fbo=$(eval "$_clear"; GONGSHO_REPO="$_G" VERB=t PATH="$_G/stubbin:$PATH"; . "$R/tools/lib.sh" >/dev/null 2>&1; printf '%s|%s|%s' "$GOCACHE" "$GOMODCACHE" "$GOPATH"); then
    if [ "$_fbo" = "$_G/.cache/go/build|$_G/.cache/go/mod|$_G/.cache/go/path" ] \
        && [ -d "$_G/.cache/go/build" ] && [ -d "$_G/.cache/go/mod" ] && [ -d "$_G/.cache/go/path" ]; then
        ok "unwritable default falls back"
    else
        bad "unwritable default falls back (got '$_fbo')"
    fi
else
    bad "unwritable default falls back (source failed)"
fi
if _fblog=$(eval "$_clear"; GONGSHO_REPO="$_G" VERB=t PATH="$_G/stubbin:$PATH"; . "$R/tools/lib.sh" 2>/dev/null); then
    if [ "$_fblog" = "[t] go cache unwritable; using repo-local fallback under $_G/.cache/go" ]; then
        ok "fallback logs once with dir"
    else
        bad "fallback logs once with dir (got '$_fblog')"
    fi
else
    bad "fallback logs once with dir (source failed)"
fi

# --- writable default untouched ---
mkdir -p "$_G/realcache"
export GO_STUB_CACHE="$_G/realcache"
if _wro=$(eval "$_clear"; GONGSHO_REPO="$_G" VERB=t PATH="$_G/stubbin:$PATH"; . "$R/tools/lib.sh" 2>"$_G/wr.err"; printf 'VARS:%s|%s|%s' "${GOCACHE:-UNSET}" "${GOMODCACHE:-UNSET}" "${GOPATH:-UNSET}"); then
    if [ "$_wro" = "VARS:UNSET|UNSET|UNSET" ] && [ ! -s "$_G/wr.err" ]; then
        ok "writable default untouched"
    else
        bad "writable default untouched (got '$_wro')"
    fi
else
    bad "writable default untouched (source failed)"
fi
unset GO_STUB_CACHE

# --- GOFLAGS gains the flag once ---
if _gf=$(eval "$_clear"; GONGSHO_REPO="$_G" VERB=t; unset GOFLAGS; . "$R/tools/lib.sh" >/dev/null 2>&1; printf '%s' "$GOFLAGS"); then
    if [ "$_gf" = "-buildvcs=false" ]; then ok "GOFLAGS set when unset"; else bad "GOFLAGS set when unset (got '$_gf')"; fi
else
    bad "GOFLAGS set when unset (source failed)"
fi
if _gf2=$(eval "$_clear"; GONGSHO_REPO="$_G" VERB=t; GOFLAGS="-mod=mod"; . "$R/tools/lib.sh" >/dev/null 2>&1; printf '%s' "$GOFLAGS"); then
    if [ "$_gf2" = "-mod=mod -buildvcs=false" ]; then ok "GOFLAGS appended preserving"; else bad "GOFLAGS appended preserving (got '$_gf2')"; fi
else
    bad "GOFLAGS appended preserving (source failed)"
fi
if _gf3=$(eval "$_clear"; GONGSHO_REPO="$_G" VERB=t; unset GOFLAGS; . "$R/tools/lib.sh" >/dev/null 2>&1; . "$R/tools/lib.sh" >/dev/null 2>&1; printf '%s' "$GOFLAGS"); then
    if [ "$_gf3" = "-buildvcs=false" ]; then ok "GOFLAGS no duplicate on resourcing"; else bad "GOFLAGS no duplicate on resourcing (got '$_gf3')"; fi
else
    bad "GOFLAGS no duplicate on resourcing (source failed)"
fi

printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
[ "$fail" -eq 0 ]
