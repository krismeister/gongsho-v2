#!/bin/sh
# lib.sh — shared helpers for the gongsho tools/ harness. Sourced, never run.
#
# Contract (docs/phase-1/tools.md): ID validation and parsing, ID<->path
# derivation, tree/socket/pidfile/proxy path builders, Caddy reload, YAML
# reads via yq, atomic writes, logging, prerequisite checks. Plus the small
# shared pieces every verb needs: HTTP over unix sockets and TCP, JSON
# comparison, pidfile stop, proxy-stanza rendering, gen-config.json writing,
# app-env sourcing, and frozen timing/pin constants.
#
# yq dialect: mikefarah yq v4 (`yq eval`, `-r`, `-e`, `-o=json`) as cited
# in the phase-plan Sources. need_yq() refuses any other flavor.
#
# Conventions: every verb starts with `set -eu`, sets VERB to its own name,
# then sources this file. Logging goes through log() (stdout, `[verb] msg`)
# and err()/die() (stderr). die() exits 1 (operational failure), usage()
# exits 2 (usage error). GONGSHO_REPO overrides repo-root detection.
#
# POSIX sh throughout (no bashisms): this file must stay clean under `sh -n`
# and runnable under dash.
#
# set -e discipline (verbs must follow it too): never call a die()/usage()
# function inside $(...) in an if-condition — the failure would be swallowed
# and the wrong branch taken. Capture to a variable in a bare assignment
# first, then test the variable.

# --- logging and exit paths ------------------------------------------------
VERB="${VERB:-tools}"
log() { printf '[%s] %s\n' "$VERB" "$*"; }
err() { printf '[%s] %s\n' "$VERB" "$*" >&2; }
die() { err "error: $*"; exit 1; }
usage() { err "error: $*"; err "run 'tools/$VERB --help' for usage."; exit 2; }

# --- repo root -------------------------------------------------------------

if [ -n "${GONGSHO_REPO:-}" ]; then
    REPO_ROOT="$GONGSHO_REPO"
else
    case $0 in
        */*) _v=$0 ;;
        *) _v=$(command -v "$0" 2>/dev/null || printf '%s' "$0") ;;
    esac
    _d=$(CDPATH= cd -- "$(dirname -- "$_v")" && pwd)
    REPO_ROOT=$(CDPATH= cd -- "$_d/.." && pwd)
    unset _v _d
fi
[ -f "$REPO_ROOT/tools/lib.sh" ] || {
    err "error: cannot locate repo root from \$0=$0"
    exit 1
}

# --- frozen constants ------------------------------------------------------
# Caddy origin (docs/phase-1/ids-and-routing.md: :8080, assumed).
CADDY_ORIGIN="http://localhost:8080"
# Supervisor timings (docs/phase-1/supervision-and-runtime.md: 10s/5s, assumed).
START_HEALTH_TIMEOUT=10
STOP_GRACE=5
# golang-migrate pin (phase-plan: the migrate version pin lives in tools/).
# Resolved 2026-11-12 from proxy.golang.org @latest.
MIGRATE_VERSION="v4.20.1"

# --- prerequisites ---------------------------------------------------------
need_cmd() { # <cmd> [what-for]
    command -v "$1" >/dev/null 2>&1 || die "missing required command '$1'${2:+ ($2)}"
}

need_yq() { # refuse to run YAML reads under any yq but mikefarah's
    command -v yq >/dev/null 2>&1 || die "missing required command 'yq' (install it with: sudo pacman -S go-yq)"
    _yv=$(yq --version 2>&1 || true)
    printf '%s' "$_yv" | grep -qi mikefarah || \
        die "unsupported yq flavor (have: ${_yv:-unknown}; want mikefarah yq - install it with: sudo pacman -S go-yq)"
    unset _yv
}

# --- ID / path validation and derivation -----------------------------------
# IDs are team_project_deployment (underscores); paths are team/project/deployment
# (slashes). Segments allow lowercase, digits, hyphens only; team `dev` is
# reserved (docs/phase-1/ids-and-routing.md).

_id_seg_ok() { # <segment> — 0 when the segment charset is legal
    case $1 in
        "" | *[!a-z0-9-]*) return 1 ;;
        *) return 0 ;;
    esac
}

_id_shape_ok() { # <id> — 0 when exactly three legal segments
    _s1=${1%%_*} _rest=${1#*_}
    [ "$_rest" != "$1" ] || return 1
    _s2=${_rest%%_*} _s3=${_rest#*_}
    [ "$_s3" != "$_rest" ] || return 1
    case $_s3 in *_*) return 1 ;; esac
    _id_seg_ok "$_s1" && _id_seg_ok "$_s2" && _id_seg_ok "$_s3"
}

_path_shape_ok() { # <path> — 0 when exactly three legal slash segments
    _s1=${1%%/*} _rest=${1#*/}
    [ "$_rest" != "$1" ] || return 1
    _s2=${_rest%%/*} _s3=${_rest#*/}
    [ "$_s3" != "$_rest" ] || return 1
    case $_s3 in */*) return 1 ;; esac
    _id_seg_ok "$_s1" && _id_seg_ok "$_s2" && _id_seg_ok "$_s3"
}

validate_id() { # <id> — dies with exit 2 unless a legal underscore ID
    case $1 in
        *"/"*) usage "want underscore ID (team_project_deployment), got path-like '$1'" ;;
    esac
    _id_shape_ok "$1" || usage "malformed deployment ID '$1' (want team_project_deployment, segments [a-z0-9-])"
    [ "${1%%_*}" != "dev" ] || usage "team 'dev' is reserved (it protects the /dev/ route prefix)"
}

validate_path() { # <path> — dies with exit 2 unless a legal slash path
    case $1 in
        *_*) case $1 in *"/"*) ;; *) usage "want slash path (team/project/deployment), got ID-like '$1'" ;; esac ;;
    esac
    _path_shape_ok "$1" || usage "malformed deployment path '$1' (want team/project/deployment, segments [a-z0-9-])"
    [ "${1%%/*}" != "dev" ] || usage "team 'dev' is reserved (it protects the /dev/ route prefix)"
}

validate_session() { # <session> — dies with exit 2 unless URL/filename-safe
    case $1 in
        "" | *[!a-z0-9-]*) usage "malformed session '$1' (want [a-z0-9-], e.g. a3f9)" ;;
    esac
    [ "${#1}" -le 32 ] || usage "malformed session '$1' (max 32 chars)"
}

validate_template_name() { # <name> — dies unless the template exists
    case $1 in
        "" | *[!a-z0-9-]*) usage "malformed template name '$1'" ;;
    esac
    [ -f "$REPO_ROOT/templates/$1/.gongsho-tpl.yaml" ] || usage "unknown template '$1' (want goa-api or react-ui)"
}

id_to_path() { printf '%s' "$1" | tr '_' '/'; }      # acme_shop_api-1 -> acme/shop/api-1
path_to_id() { printf '%s' "$1" | tr '/' '_'; }      # acme/shop/api-1 -> acme_shop_api-1
id_slug() { printf '%s' "$1" | tr 'a-z-' 'A-Z_'; }   # e2e env slug: ACME_SHOP_API_1

# --- path builders (all absolute; pass validated IDs/paths/sessions) --------
app_dir() { printf '%s/apps/%s' "$REPO_ROOT" "$(id_to_path "$1")"; }          # <id>
bin_dir() { printf '%s/bin/%s' "$REPO_ROOT" "$(id_to_path "$1")"; }           # <id>
data_dir() { printf '%s/data/%s' "$REPO_ROOT" "$(id_to_path "$1")"; }         # <id>
proxy_file() { printf '%s/proxy/deployments/%s' "$REPO_ROOT" "$1"; }          # <id>
socket_path() { printf '%s/proxy/sockets/%s.sock' "$REPO_ROOT" "$1"; }        # <id>
pidfile_path() { printf '%s/proxy/sockets/%s.pid' "$REPO_ROOT" "$1"; }        # <id>
log_path() { printf '%s/proxy/sockets/%s.log' "$REPO_ROOT" "$1"; }            # <id>
dev_proxy_file() { printf '%s/proxy/dev.d/%s-%s' "$REPO_ROOT" "$1" "$2"; }    # <session> <id>
dev_socket_path() { printf '%s/proxy/sockets/%s.dev-%s.sock' "$REPO_ROOT" "$2" "$1"; } # <session> <id>
dev_pidfile_path() { printf '%s/proxy/sockets/%s.dev-%s.pid' "$REPO_ROOT" "$2" "$1"; } # <session> <id>
dev_log_path() { printf '%s/proxy/sockets/%s.dev-%s.log' "$REPO_ROOT" "$2" "$1"; }     # <session> <id>
run_session_dir() { printf '%s/run/%s' "$REPO_ROOT" "$1"; }                   # <session>
artifacts_dir() { printf '%s/run/%s/artifacts' "$REPO_ROOT" "$1"; }           # <session>
dev_bundle_dir() { printf '%s/run/%s/bundles/%s' "$REPO_ROOT" "$1" "$(id_to_path "$2")"; } # <session> <id>
dev_db_path() { printf '%s/run/%s/data/%s/app.db' "$REPO_ROOT" "$1" "$(id_to_path "$2")"; } # <session> <id>
template_dir() { printf '%s/templates/%s' "$REPO_ROOT" "$1"; }                # <template>
stanza_src() { printf '%s/templates/%s/config/caddy/stanza' "$REPO_ROOT" "$1"; } # <template>
health_spec() { printf '%s/templates/%s/config/health.json' "$REPO_ROOT" "$1"; } # <template>

ensure_dir() { mkdir -p -- "$1"; }

# --- YAML reads (yq) and pin validation -------------------------------------
pin_file() { printf '%s/apps/%s/.gongsho-deployment.yaml' "$REPO_ROOT" "$(id_to_path "$1")"; } # <id>
deployment_exists() { [ -f "$(pin_file "$1")" ]; }

pin_get() { # <id> <yq-expr> — raw value from the deployment pin
    need_yq
    _pin=$(pin_file "$1")
    deployment_exists "$1" || die "unknown deployment '$1' (no $_pin; create it with: tools/create $(id_to_path "$1") --template <name>)"
    _out=$(yq eval -r "$2" "$_pin" 2>&1) || die "cannot parse $_pin: $_out"
    printf '%s' "$_out"
    unset _pin _out
}

pin_has() { # <id> <yq-expr> — 0 when the key is present (empty maps count)
    yq eval -e "$2" "$(pin_file "$1")" >/dev/null 2>&1
}

pin_id() { pin_get "$1" '.id'; }                                   # <id>
pin_path() { pin_get "$1" '.path'; }                               # <id>
pin_template() { pin_get "$1" '.template'; }                       # <id>
pin_version() { pin_get "$1" '.templateVersion'; }                  # <id>
pin_db_path() { pin_get "$1" '.db.path // ""'; }                   # <id> ("" for UIs)

tpl_get() { # <template> <yq-expr> — raw value from the template manifest
    need_yq
    validate_template_name "$1"
    _out=$(yq eval -r "$2" "$REPO_ROOT/templates/$1/.gongsho-tpl.yaml" 2>&1) || die "cannot parse template manifest for '$1': $_out"
    printf '%s' "$_out"
    unset _out
}

template_kind() { # <template> — echoes api|ui; dies on anything else
    validate_template_name "$1"
    case $1 in
        goa-api) printf 'api' ;;
        react-ui) printf 'ui' ;;
        *) die "unknown template '$1' (want goa-api or react-ui)" ;;
    esac
}

validate_pin() { # <id> — dies unless the pin is fully consistent
    validate_id "$1"
    _pin=$(pin_file "$1")
    deployment_exists "$1" || die "unknown deployment '$1' (no $_pin)"
    yq eval '.' "$_pin" >/dev/null 2>&1 || die "cannot parse $_pin"
    [ "$(pin_get "$1" '.id')" = "$1" ] || die "pin id mismatch in $_pin (want '$1')"
    [ "$(pin_get "$1" '.path')" = "$(id_to_path "$1")" ] || die "pin path disagrees with id in $_pin"
    _t=$(pin_template "$1")
    validate_template_name "$_t"
    pin_has "$1" '.templateVersion' || die "pin misses templateVersion in $_pin"
    pin_has "$1" '.vars' || die "pin misses vars in $_pin"
    pin_has "$1" '.created' || die "pin misses created in $_pin"
    _kind=$(template_kind "$_t")
    if [ "$_kind" = "api" ]; then
        [ "$(pin_get "$1" '.db.type // ""')" = "SQLite" ] || die "API pin misses db.type SQLite in $_pin"
        [ -n "$(pin_db_path "$1")" ] || die "API pin misses db.path in $_pin"
    else
        if pin_has "$1" '.db'; then die "UI pin must not carry db in $_pin"; fi
    fi
    unset _pin _t _kind
}

# --- atomic writes (temp-then-rename; tmp lives beside the destination) ------
tmp_in_dir() { # <dir> — echoes a fresh tmp path (caller writes it, then atomic_mv)
    ensure_dir "$1"
    mktemp "$1/.tmp.XXXXXX"
}

atomic_mv() { # <tmp> <dest> — same-filesystem rename over the destination
    ensure_dir "$(dirname -- "$2")"
    mv -f -- "$1" "$2"
}

# --- Caddy -----------------------------------------------------------------
caddy_reload() {
    need_cmd caddy "documented prerequisite (proxying)"
    _out=$(caddy reload --config "$REPO_ROOT/proxy/Caddyfile" 2>&1) || \
        die "caddy reload failed: $_out (is Caddy running? start it with: caddy run --config proxy/Caddyfile)"
    log "reloaded caddy"
    unset _out
}

# --- time, sessions, hashing -------------------------------------------------
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

# --- HTTP (direct unix socket or TCP via Caddy) -------------------------------
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
    _hpath=$(yq eval -r '.path' "$2" 2>/dev/null) || return 1
    _hstatus=$(yq eval -r '.status' "$2" 2>/dev/null) || return 1
    _exp=$(mktemp) || return 1
    yq eval -o=json '.body' "$2" >"$_exp" 2>/dev/null || { rm -f -- "$_exp"; return 1; }
    _end=$(( $(date +%s) + $3 ))
    while [ "$(date +%s)" -lt "$_end" ]; do
        _body=$(mktemp) || { rm -f -- "$_exp"; return 1; }
        _code=$(direct_get "$1" "$_hpath" "$_body")
        if [ "$_code" = "$_hstatus" ] && json_equal "$_exp" "$_body"; then
            rm -f -- "$_body" "$_exp"
            unset _hpath _hstatus _exp _end _body _code
            return 0
        fi
        rm -f -- "$_body"
        sleep 0.25
    done
    rm -f -- "$_exp"
    unset _hpath _hstatus _exp _end _body _code
    return 1
}

# --- pidfile processes -------------------------------------------------------
pid_is_live() { # <pid> — 0 when the pid exists and accepts signals
    case $1 in "" | *[!0-9]*) return 1 ;; esac
    kill -0 "$1" 2>/dev/null
}

read_pidfile() { # <pidfile> — echoes the pid, or nothing when absent/unreadable
    [ -f "$1" ] || return 0
    _pid=$(tr -d ' \t\n' <"$1" 2>/dev/null || true)
    case $_pid in "" | *[!0-9]*) return 0 ;; *) printf '%s' "$_pid" ;; esac
    unset _pid
}

stop_pidfile() { # <pidfile> <grace-s> — SIGTERM, grace, SIGKILL; removes pidfile
    _pid=$(read_pidfile "$1")
    if [ -z "$_pid" ]; then
        log "not running (no pidfile)"
        return 0
    fi
    if ! pid_is_live "$_pid"; then
        rm -f -- "$1"
        log "removed stale pidfile (pid $_pid dead)"
        unset _pid
        return 0
    fi
    kill -TERM "$_pid" 2>/dev/null || { err "error: cannot signal pid $_pid"; unset _pid; return 1; }
    _end=$(( $(date +%s) + $2 ))
    while pid_is_live "$_pid" && [ "$(date +%s)" -lt "$_end" ]; do sleep 0.2; done
    if pid_is_live "$_pid"; then
        kill -KILL "$_pid" 2>/dev/null || { err "error: cannot kill pid $_pid"; unset _pid _end; return 1; }
        _end=$(( $(date +%s) + 2 ))
        while pid_is_live "$_pid" && [ "$(date +%s)" -lt "$_end" ]; do sleep 0.2; done
    fi
    if pid_is_live "$_pid"; then
        err "error: pid $_pid survived SIGKILL"
        unset _pid _end
        return 1
    fi
    rm -f -- "$1"
    log "stopped (pid $_pid)"
    unset _pid _end
    return 0
}

# --- stanza rendering ----------------------------------------------------------
# The two landed stanzas use different placeholder dialects (goa-api: {{X}},
# react-ui: ${X}); render the superset so both dialects resolve, then refuse
# to emit a file with leftovers (an undeclared template input).
#
# Stable stanzas render once at create time. dev-up never re-renders from
# the template: it derives the dev stanza from the already-rendered stable
# proxy file via render_dev_stanza below.

_sed_escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }
_bre_escape() { printf '%s' "$1" | sed -e 's/[][\\.*^$|]/\\&/g'; }

_has_placeholders() { # <file> — 0 when any {{ or ${ placeholder remains in directive lines
    # Full-line comments are not directives: the react-ui stanza documents
    # its own `${VAR}` syntax in a comment, which must pass, while any
    # placeholder-shaped text in a directive line (known or unknown) fails.
    grep -v '^[[:space:]]*#' "$1" | grep -q -F -e '{{' -e '${'
}

render_stanza() { # <template> <id> <path> <dest> — render owned stanza to dest
    _src=$(stanza_src "$1")
    [ -f "$_src" ] || die "template '$1' has no proxy stanza source ($_src)"
    _tmp=$(tmp_in_dir "$(dirname -- "$4")")
    sed -e "s|{{ID}}|$(_sed_escape "$2")|g" \
        -e "s|{{PATH}}|$(_sed_escape "$3")|g" \
        -e "s|{{REPO}}|$(_sed_escape "$REPO_ROOT")|g" \
        -e "s|\${ID}|$(_sed_escape "$2")|g" \
        -e "s|\${PATH}|$(_sed_escape "$3")|g" \
        -e "s|\${REPO}|$(_sed_escape "$REPO_ROOT")|g" \
        "$_src" >"$_tmp"
    if _has_placeholders "$_tmp"; then
        rm -f -- "$_tmp"
        die "template '$1' stanza needs undeclared inputs (unrendered placeholders remain)"
    fi
    atomic_mv "$_tmp" "$4"
    unset _src _tmp
}

render_dev_stanza() { # <session> <id> <dest> — derive the dev stanza from the stable proxy file
    validate_session "$1"
    validate_id "$2"
    _src=$(proxy_file "$2")
    [ -f "$_src" ] || die "stable proxy file '$_src' is missing (it renders once at create time; restore it from git - proxy/deployments/ is committed)"
    _path=$(id_to_path "$2")
    _t=$(pin_template "$2")
    _kind=$(template_kind "$_t")
    # Every substitution is asserted: the stable pattern must be present and
    # the dev result must land, else the stable file was tampered with. The
    # temp file is allocated only after the pre-asserts pass, so failures
    # leave neither temp files nor empty dest dirs behind.
    _prefix="handle_path /$_path/*"
    _devprefix="handle_path /dev/$1/$_path/*"
    grep -q -F -- "$_prefix" "$_src" || die "stable proxy file '$_src' has no '$_prefix' line (tampered?)"
    if [ "$_kind" = "api" ]; then
        _sock="$2.sock"
        _devsock="$2.dev-$1.sock"
        grep -q -F -- "$_sock" "$_src" || die "stable proxy file '$_src' has no '$_sock' upstream (tampered?)"
        _tmp=$(tmp_in_dir "$(dirname -- "$3")")
        sed -e "s|$(_bre_escape "$_prefix")|$(_sed_escape "$_devprefix")|g" \
            -e "s|$(_bre_escape "$_sock")|$(_sed_escape "$_devsock")|g" \
            "$_src" >"$_tmp"
        grep -q -F -- "$_devsock" "$_tmp" || { rm -f -- "$_tmp"; die "dev derivation failed to rewrite the socket in '$_src'"; }
    else
        _root="$REPO_ROOT/bin/$_path"
        _devroot="$REPO_ROOT/run/$1/bundles/$_path"
        grep -q -F -- "$_root" "$_src" || die "stable proxy file '$_src' has no '$_root' root (tampered?)"
        _tmp=$(tmp_in_dir "$(dirname -- "$3")")
        sed -e "s|$(_bre_escape "$_prefix")|$(_sed_escape "$_devprefix")|g" \
            -e "s|$(_bre_escape "$_root")|$(_sed_escape "$_devroot")|g" \
            "$_src" >"$_tmp"
        grep -q -F -- "$_devroot" "$_tmp" || { rm -f -- "$_tmp"; die "dev derivation failed to rewrite the root in '$_src'"; }
    fi
    grep -q -F -- "$_devprefix" "$_tmp" || { rm -f -- "$_tmp"; die "dev derivation failed to rewrite the prefix in '$_src'"; }
    atomic_mv "$_tmp" "$3"
    unset _src _path _t _kind _tmp _prefix _devprefix _sock _devsock _root _devroot
}

# --- gen-config.json (harness-owned UI runtime config) -------------------------
# Maps each consumed API (<api-id> from spec/*.openapi.json) to its
# same-origin path. <prefix> is "" for stable bundles, "/dev/<session>" for
# dev bundles. Byte-stable: sorted keys, and the empty map matches the
# scaffold placeholder exactly.

_wgc_die() { # <msg> — remove write_gen_config's temp files, then die
    rm -f -- "${_tmp:-/nonexistent}" "${_list:-/nonexistent}" "${_sorted:-/nonexistent}" 2>/dev/null || true
    die "$1"
}

write_gen_config() { # <dest> <ui-app-dir> <prefix>
    _dir=$2 _prefix=$3
    _tmp=$(tmp_in_dir "$(dirname -- "$1")")
    _list=$(mktemp) || _wgc_die "cannot create temp file"
    for _spec in "$_dir/spec/"*.openapi.json; do
        [ -e "$_spec" ] || break
        _api=$(basename -- "$_spec" .openapi.json)
        _id_shape_ok "$_api" || _wgc_die "snapshot '$_spec' names malformed API ID '$_api'"
        deployment_exists "$_api" || _wgc_die "dangling snapshot '$_spec' (no deployment '$_api')"
        _pt=$(pin_template "$_api")
        [ "$_pt" = "goa-api" ] || _wgc_die "snapshot '$_spec' refers to non-API deployment '$_api'"
        printf '%s %s\n' "$_api" "$_prefix/$(id_to_path "$_api")" >>"$_list"
        unset _api _pt
    done
    if [ -s "$_list" ]; then
        _sorted=$(mktemp) || _wgc_die "cannot create temp file"
        sort "$_list" >"$_sorted" || _wgc_die "cannot sort snapshot list"
        {
            printf '{\n  "apis": {\n'
            _first=1
            while read -r _id _apipath; do
                if [ "$_first" -eq 1 ]; then _first=0; else printf ',\n'; fi
                printf '    "%s": "%s"' "$_id" "$_apipath"
            done <"$_sorted"
            printf '\n  }\n}\n'
        } >"$_tmp"
        rm -f -- "$_sorted"
        unset _sorted
    else
        printf '{\n  "apis": {}\n}\n' >"$_tmp"
    fi
    rm -f -- "$_list"
    atomic_mv "$_tmp" "$1"
    unset _dir _prefix _tmp _list _spec _first _id _apipath
}

# --- app environment -----------------------------------------------------------
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

# --- sourced, never run ----------------------------------------------------------
return 0 2>/dev/null || { echo "tools/lib.sh is sourced, never run" >&2; exit 2; }
