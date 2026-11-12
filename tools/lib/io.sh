# lib/io.sh — directories, atomic writes, time, sessions, hashing.
# Sourced via tools/lib.sh; never sourced or run alone.

ensure_dir() { mkdir -p -- "$1"; }

tmp_in_dir() { # <dir> — echoes a fresh tmp path (caller writes it, then atomic_mv)
    ensure_dir "$1"
    mktemp "$1/.tmp.XXXXXX"
}

atomic_mv() { # <tmp> <dest> — same-filesystem rename over the destination
    ensure_dir "$(dirname -- "$2")"
    mv -f -- "$1" "$2"
}

utc_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }   # RFC3339 for pin `created`
ts_short() { date -u +%Y%m%dT%H%M%SZ; }      # backup/archive suffix

mint_session() { # fresh 8-hex dev session (collision-safe across runs)
    need_cmd od "session minting"
    od -An -tx1 -N4 /dev/urandom | tr -d ' \n'
}

sha256_file() { # <file> — hex digest of the file bytes
    need_cmd sha256sum "hashing"
    sha256sum -- "$1" | cut -d' ' -f1
}

ensure_go_caches() {
    # Sandboxed sessions cannot write the default Go cache, which breaks
    # goa gen and go build. When both caches are preset, or go is absent,
    # there is nothing to do. Otherwise probe the default cache dir for
    # writability and fall back to a repo-local one when needed.
    if [ -n "${GOCACHE:-}" ] && [ -n "${GOMODCACHE:-}" ]; then
        return 0
    fi
    command -v go >/dev/null 2>&1 || return 0
    _L_gocache=$(go env GOCACHE 2>/dev/null || true)
    if [ -n "$_L_gocache" ] && [ -w "$_L_gocache" ]; then
        return 0
    fi
    _L_godir="$REPO_ROOT/.cache/go"
    mkdir -p -- "$_L_godir/build" "$_L_godir/mod" "$_L_godir/path" || die "cannot create Go cache dirs under $_L_godir"
    GOCACHE="$_L_godir/build"
    GOMODCACHE="$_L_godir/mod"
    GOPATH="$_L_godir/path"
    export GOCACHE GOMODCACHE GOPATH
    log "go cache unwritable; using repo-local fallback under $_L_godir"
}
