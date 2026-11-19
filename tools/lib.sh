#!/bin/sh
# lib.sh — shared helpers for the gongsho tools/ harness. Sourced, never run.
#
# Contract (docs/ai/contracts/tools.md): ID validation and parsing, ID<->path
# derivation, tree/socket/pidfile/proxy path builders, Caddy reload, YAML
# reads via yq, atomic writes, logging, prerequisite checks. Plus the small
# shared pieces every verb needs: HTTP over unix sockets and TCP, JSON
# comparison, pidfile stop, proxy-stanza rendering, gen-config.json writing,
# app-env sourcing, and frozen timing/pin constants.
#
# This file is a thin wrapper: it locates the checkout, sets globals and
# frozen constants, and sources the modules in tools/lib/. Verbs and tests
# keep sourcing tools/lib.sh exactly as before.
#
# Conventions: every verb starts with `set -eu`, sets VERB to its own name,
# then sources this file. Logging goes through log() (stdout, `[verb] msg`)
# and err()/die() (stderr). die() exits 1 (operational failure), usage()
# exits 2 (usage error). GONGSHO_REPO overrides repo-root detection;
# GONGSHO_HOME overrides home-root detection (default: parent of the repo).
#
# POSIX sh throughout (no bashisms): this file must stay clean under `sh -n`
# and runnable under dash.
#
# set -e discipline (verbs must follow it too): never call a die()/usage()
# function inside $(...) in an if-condition — the failure would be swallowed
# and the wrong branch taken. Capture to a variable in a bare assignment
# first, then test the variable.

# --- logging first: error reporting for everything below -------------------
VERB="${VERB:-tools}"

# Locate the module dir from the caller's path ($0): verbs live in tools/
# and suites in tools/tests/, so both depths are tried. Modules always come
# from this checkout, never from $GONGSHO_REPO (which may point at a fake).
case $0 in
    */*) _L_v=$0 ;;
    *) _L_v=$(command -v "$0" 2>/dev/null || printf '%s' "$0") ;;
esac
_L_lib_dir=
for _L_cand in "$(dirname -- "$_L_v")/lib" "$(dirname -- "$_L_v")/../lib"; do
    if [ -f "$_L_cand/log.sh" ]; then
        _L_lib_dir=$(CDPATH= cd -- "$_L_cand" && pwd)
        break
    fi
done
[ -n "$_L_lib_dir" ] || { echo "error: cannot locate tools/lib from \$0=$0" >&2; exit 1; }
. "$_L_lib_dir/log.sh"

# --- repo root -------------------------------------------------------------
if [ -n "${GONGSHO_REPO:-}" ]; then
    REPO_ROOT="$GONGSHO_REPO"
else
    REPO_ROOT=$(CDPATH= cd -- "$_L_lib_dir/../.." && pwd)
fi
[ -f "$REPO_ROOT/tools/lib.sh" ] || {
    err "error: cannot locate repo root from \$0=$0"
    exit 1
}

# --- machine config: root .env (optional) plus built-in defaults ------------
# Values come from $REPO_ROOT/.env when it exists (.example.env documents
# the keys); per-var defaults apply for anything unset or when absent.
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    . "$REPO_ROOT/.env" || { echo "error: cannot source $REPO_ROOT/.env" >&2; exit 1; }
    set +a
fi
# Go fails where VCS stub dirs (.hg plus .git) coexist in a checkout, so
# Go itself prescribes -buildvcs=false there; keep any existing flags.
case " ${GOFLAGS:-} " in
    *" -buildvcs=false "*) ;;
    *) GOFLAGS="${GOFLAGS:-}${GOFLAGS:+ }-buildvcs=false"; export GOFLAGS ;;
esac
# Workspace home (default: parent of the repo checkout; machine config
# wins). apps/ and data/ resolve under this root; bin/, run/, proxy/,
# templates/, and tools/ stay under REPO_ROOT.
GONGSHO_HOME="${GONGSHO_HOME:-$(dirname -- "$REPO_ROOT")}"
# Caddy origin (default port 8181; machine config wins).
CADDY_ORIGIN="${GONGSHO_SCHEME:-http}://${GONGSHO_HOST:-localhost}:${GONGSHO_PORT:-8181}"
# Supervisor timings in seconds (defaults 10/5).
START_HEALTH_TIMEOUT="${GONGSHO_START_HEALTH_TIMEOUT:-10}"
STOP_GRACE="${GONGSHO_STOP_GRACE:-5}"
# golang-migrate pin (docs/planning/templates.md: the migrate version pin lives in tools/).
# Default resolved 2026-11-12 from proxy.golang.org @latest.
MIGRATE_VERSION="${GONGSHO_MIGRATE_VERSION:-v4.20.1}"
# pnpm pin (vendored by cache-warm into .cache/pnpm). Stays on the v9
# line: v12's store-operation locking fails under sandboxed shells.
PNPM_VERSION="${GONGSHO_PNPM_VERSION:-9.15.9}"
# lefthook pin (vendored by cache-warm into tools/bin/; hooks run it).
# Stays below the go-json-experiment dependency (v1.13+): this toolchain
# build lacks that experimental stdlib surface, so newer lefthook will
# not compile here. Float forward when the toolchain does.
LEFTHOOK_VERSION="${GONGSHO_LEFTHOOK_VERSION:-v1.12.4}"

# --- modules ---------------------------------------------------------------
for _L_m in ids paths pin io caddy health proc render env tpl-goa-api tpl-langchain-api tpl-react-ui tpl; do
    . "$_L_lib_dir/$_L_m.sh" || { err "error: cannot source tools/lib/$_L_m.sh"; exit 1; }
done

# --- sourced, never run ----------------------------------------------------------
# Fall back to repo-local Go caches when the default cache is unusable.
ensure_go_caches

return 0 2>/dev/null || { echo "tools/lib.sh is sourced, never run" >&2; exit 2; }
