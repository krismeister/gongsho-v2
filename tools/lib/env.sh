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
