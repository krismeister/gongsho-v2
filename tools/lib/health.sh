# lib/health.sh — HTTP getters, JSON comparison, direct-socket health wait.
# Sourced via tools/lib.sh; never sourced or run alone.
#
# Both getters write the response body to <outfile> and echo the HTTP status
# code; transport failures echo 000 so callers never trip `set -e`.

direct_get() { # <socket> <reqpath> <outfile>
    need_cmd curl "health probes"
    curl -sS --max-time 10 --unix-socket "$1" -o "$3" -w '%{http_code}' "http://localhost$2" 2>/dev/null || true
}

http_get() { # <url> <outfile>
    need_cmd curl "health probes"
    curl -sS --max-time 10 -o "$2" -w '%{http_code}' "$1" 2>/dev/null || true
}

json_equal() { # <file> <file> — 0 when both parse to equal JSON
    need_yq
    [ "$(yq eval -o=json '.' "$1" 2>/dev/null || printf 'INVALID-1')" = \
      "$(yq eval -o=json '.' "$2" 2>/dev/null || printf 'INVALID-2')" ]
}

wait_direct_health() { # <socket> <health.json> <timeout-s> — 0 when healthy in time
    [ -f "$2" ] || return 1
    _L_hpath=$(yq eval -r '.path' "$2" 2>/dev/null) || return 1
    _L_hstatus=$(yq eval -r '.status' "$2" 2>/dev/null) || return 1
    _L_exp=$(mktemp) || return 1
    yq eval -o=json '.body' "$2" >"$_L_exp" 2>/dev/null || { rm -f -- "$_L_exp"; return 1; }
    _L_end=$(( $(date +%s) + $3 ))
    while [ "$(date +%s)" -lt "$_L_end" ]; do
        _L_body=$(mktemp) || { rm -f -- "$_L_exp"; return 1; }
        _L_code=$(direct_get "$1" "$_L_hpath" "$_L_body")
        if [ "$_L_code" = "$_L_hstatus" ] && json_equal "$_L_exp" "$_L_body"; then
            rm -f -- "$_L_body" "$_L_exp"
            return 0
        fi
        rm -f -- "$_L_body"
        sleep 0.25
    done
    rm -f -- "$_L_exp"
    return 1
}
