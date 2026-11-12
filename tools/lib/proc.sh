# lib/proc.sh — pidfile processes. Sourced via tools/lib.sh; never sourced or run alone.

pid_is_live() { # <pid> — 0 when the pid exists and accepts signals
    case $1 in "" | *[!0-9]*) return 1 ;; esac
    kill -0 "$1" 2>/dev/null
}

read_pidfile() { # <pidfile> — echoes the pid, or nothing when absent/unreadable
    [ -f "$1" ] || return 0
    _L_pid=$(tr -d ' \t\n' <"$1" 2>/dev/null || true)
    case $_L_pid in "" | *[!0-9]*) return 0 ;; *) printf '%s' "$_L_pid" ;; esac
}

stop_pidfile() { # <pidfile> <grace-s> — SIGTERM, grace, SIGKILL; removes pidfile
    _L_pid=$(read_pidfile "$1")
    if [ -z "$_L_pid" ]; then
        log "not running (no pidfile)"
        return 0
    fi
    if ! pid_is_live "$_L_pid"; then
        rm -f -- "$1"
        log "removed stale pidfile (pid $_L_pid dead)"
        return 0
    fi
    kill -TERM "$_L_pid" 2>/dev/null || { err "error: cannot signal pid $_L_pid"; return 1; }
    _L_end=$(( $(date +%s) + $2 ))
    while pid_is_live "$_L_pid" && [ "$(date +%s)" -lt "$_L_end" ]; do sleep 0.2; done
    if pid_is_live "$_L_pid"; then
        kill -KILL "$_L_pid" 2>/dev/null || { err "error: cannot kill pid $_L_pid"; return 1; }
        _L_end=$(( $(date +%s) + 2 ))
        while pid_is_live "$_L_pid" && [ "$(date +%s)" -lt "$_L_end" ]; do sleep 0.2; done
    fi
    if pid_is_live "$_L_pid"; then
        err "error: pid $_L_pid survived SIGKILL"
        return 1
    fi
    rm -f -- "$1"
    log "stopped (pid $_L_pid)"
    return 0
}
