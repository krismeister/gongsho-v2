# lib/caddy.sh — Caddy reload. Sourced via tools/lib.sh; never sourced or run alone.

caddy_reload() {
    need_cmd caddy "documented prerequisite (proxying)"
    _L_out=$(caddy reload --config "$REPO_ROOT/proxy/Caddyfile" 2>&1) || \
        die "caddy reload failed: $_L_out (is Caddy running? start it with: caddy run --config proxy/Caddyfile)"
    log "reloaded caddy"
}
