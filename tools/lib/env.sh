# lib/env.sh — app environment (.env ensure/source, injected exports).
# Sourced via tools/lib.sh; never sourced or run alone.
#
# start/dev-up ensure .env (copy from .example.env), source it for tunables,
# then export the pin-derived injected variables over it.

source_app_env() { # <app-dir>
    if [ ! -f "$1/.env" ]; then
        [ -f "$1/.example.env" ] || die "no .env and no .example.env in $1"
        cp -- "$1/.example.env" "$1/.env"
        log "created .env from .example.env"
    fi
    [ -r "$1/.env" ] || die "cannot read $1/.env"
    set -a
    . "$1/.env"
    set +a
}

export_injected() { # <id> <socket-path> <db-path>
    SOCKET_PATH=$2
    DB_PATH=$3
    DEPLOYMENT_ID=$1
    TEMPLATE=$(pin_template "$1")
    TEMPLATE_VERSION=$(pin_version "$1")
    export SOCKET_PATH DB_PATH DEPLOYMENT_ID TEMPLATE TEMPLATE_VERSION
}

secrets_source_hash() { # stdout: hex digest over the secretsread sources that affect the binary
    need_cmd sha256sum "hashing"
    _srdir="$REPO_ROOT/tools/secretsread"
    [ -d "$_srdir" ] || die "no tools/secretsread in $REPO_ROOT"
    for _srf in main.go secrets/secrets.go go.mod go.sum; do
        [ -f "$_srdir/$_srf" ] || die "missing tools/secretsread/$_srf"
    done
    _srh=$(CDPATH= cd -- "$_srdir" && cat -- main.go secrets/secrets.go go.mod go.sum | sha256sum | cut -d' ' -f1)
    [ -n "$_srh" ] || die "cannot hash tools/secretsread sources"
    printf '%s\n' "$_srh"
}

secrets_read() { # <db> <org> <team> <project> <deployment> <name> — stdout: stored value; exit mirrors the reader (0 hit, 1 operational, 2 usage)
    [ $# -eq 6 ] || { err "usage: secrets_read <db> <org> <team> <project> <deployment> <name>"; return 2; }
    _srbin="$REPO_ROOT/tools/bin/secretsread"
    _srwant="src-$(secrets_source_hash)"
    _srhave=""
    if [ -x "$_srbin" ] && [ -f "$_srbin.version" ]; then
        _srhave=$(cat -- "$_srbin.version" 2>/dev/null || true)
    fi
    if [ -n "$_srhave" ] && [ "$_srhave" = "$_srwant" ]; then
        "$_srbin" --db "$1" --org "$2" --team "$3" --project "$4" --deployment "$5" --name "$6"
    else
        need_cmd go "Go toolchain (fallback when no prebuilt secretsread matches)"
        ( CDPATH= cd -- "$REPO_ROOT/tools/secretsread" && go run . --db "$1" --org "$2" --team "$3" --project "$4" --deployment "$5" --name "$6" )
    fi
}

secrets_ensure_master_key() { # ensure GONGSHO_SECRETS_MASTER_KEY in root .env; stdout: fingerprint; exit 0 ok, 1 malformed
    need_cmd sha256sum "hashing"
    need_cmd base64 "key decoding"
    need_cmd od "byte inspection"
    _skenv="$REPO_ROOT/.env"
    [ -f "$_skenv" ] || die "no $_skenv (run tools/setup to create machine config first)"
    _skval=$(grep '^GONGSHO_SECRETS_MASTER_KEY=' "$_skenv" | tail -n 1 | cut -d= -f2-)
    if [ -n "$_skval" ]; then
        case "$_skval" in
            *[!A-Za-z0-9+/=]*) die "GONGSHO_SECRETS_MASTER_KEY in $_skenv is not base64 (fix by hand; refusing to overwrite)" ;;
        esac
        _sklen=$(printf '%s' "$_skval" | base64 -d 2>/dev/null | wc -c | tr -d ' ') || die "GONGSHO_SECRETS_MASTER_KEY in $_skenv does not decode (fix by hand; refusing to overwrite)"
        [ "$_sklen" = "32" ] || die "GONGSHO_SECRETS_MASTER_KEY in $_skenv decodes to $_sklen bytes, want 32 (fix by hand; refusing to overwrite)"
        _skfp=$(printf '%s' "$_skval" | sha256sum | cut -c1-16)
        log "master key present in $_skenv (fingerprint $_skfp)"
        printf '%s\n' "$_skfp"
        return 0
    fi
    _sknew=$(head -c32 /dev/urandom | base64) || die "cannot generate master key"
    [ -n "$_sknew" ] || die "cannot generate master key"
    _sktmp=$(tmp_in_dir "$(dirname -- "$_skenv")")
    cat -- "$_skenv" >"$_sktmp" || die "cannot stage $_skenv"
    if [ -s "$_sktmp" ]; then
        _sklast=$(tail -c 1 "$_sktmp" | od -An -tx1 | tr -d ' \n')
        [ "$_sklast" = "0a" ] || printf '\n' >>"$_sktmp"
    fi
    printf '%s\n' "GONGSHO_SECRETS_MASTER_KEY=$_sknew" >>"$_sktmp"
    atomic_mv "$_sktmp" "$_skenv"
    _skfp=$(printf '%s' "$_sknew" | sha256sum | cut -c1-16)
    log "generated master key in $_skenv (fingerprint $_skfp)"
    printf '%s\n' "$_skfp"
}
