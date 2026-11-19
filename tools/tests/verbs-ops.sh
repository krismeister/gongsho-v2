#!/bin/sh
# verbs-ops.sh — hermetic operational coverage: true positives via fixture
# trees plus a stub caddy, a python fake API binary, and a go-stub migrate
# emulator. Fake repo only; real toolchains never execute.
set -eu
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
unset GONGSHO_HOME GONGSHO_SCHEME GONGSHO_HOST GONGSHO_PORT GONGSHO_START_HEALTH_TIMEOUT GONGSHO_STOP_GRACE GONGSHO_MIGRATE_VERSION GONGSHO_PNPM_VERSION
F=$(mktemp -d)
_killall() {
    for _pf in "$F"/proxy/sockets/*.pid; do
        [ -e "$_pf" ] || break
        _p=$(tr -d ' \t\n' <"$_pf" 2>/dev/null || true)
        case $_p in ""|*[!0-9]*) ;; *) kill -KILL "$_p" 2>/dev/null || true;; esac
    done
}
trap '_killall; rm -rf "$F"' EXIT
mkdir -p "$F/tools" "$F/templates" "$F/apps/acme/shop/api-1" "$F/apps/acme/shop/ui-1"
cp "$R/tools/lib.sh" "$F/tools/lib.sh"
# Mirror every repo template: verbs (e.g. cache-warm) iterate the template
# set, so a fixture frozen at two templates goes stale on the third.
for _tpl in "$R"/templates/*/; do cp -r -- "$_tpl" "$F/templates/"; done; unset _tpl
cat >"$F/apps/acme/shop/api-1/.gongsho-deployment.yaml" <<'EOF'
id: acme_shop_api-1
path: acme/shop/api-1
template: goa-api
templateVersion: "1.0"
vars: {}
db:
  type: SQLite
  path: acme_shop_api-1/app.db
created: "2026-11-11T12:00:00Z"
EOF
cat >"$F/apps/acme/shop/ui-1/.gongsho-deployment.yaml" <<'EOF'
id: acme_shop_ui-1
path: acme/shop/ui-1
template: react-ui
templateVersion: "1.0"
vars: {}
created: "2026-11-11T12:00:00Z"
EOF
export GONGSHO_REPO=$F GONGSHO_HOME=$F
export PATH="$R/tools/tests/fixtures/bin:$PATH"
export CADDY_STUB_LOG="$F/caddy.log"

pass=0; fail=0
ok() { pass=$((pass+1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1"; }
runv() { # <verb> [args...] — sets _out (combined output) and _rc (exit)
    _v=$1; shift
    _rc=0
    _out=$(sh "$R/tools/$_v" "$@" 2>&1) || _rc=$?
    unset _v
}
expect_rc() { # <label> <want-rc> <verb> [args...]
    _label=$1; _want=$2; shift 2
    runv "$@"
    if [ "$_rc" = "$_want" ]; then ok "$_label"; else bad "$_label (exit $_rc, want $_want: $_out)"; fi
    unset _label _want
}
expect_rc_grep() { # <label> <want-rc> <pattern> <verb> [args...]
    _label=$1; _want=$2; _pat=$3; shift 3
    runv "$@"
    if [ "$_rc" = "$_want" ] && printf '%s' "$_out" | grep -q -F -- "$_pat"; then
        ok "$_label"
    else
        bad "$_label (exit $_rc, want $_want + '$_pat': $_out)"
    fi
    unset _label _want _pat
}

# --- create UI positive (stub caddy) ---
expect_rc "create ui ok" 0 create verify/loop/ui-9 --template react-ui
if [ -f "$F/apps/verify/loop/ui-9/package.json" ] && [ -f "$F/apps/verify/loop/ui-9/src/App.tsx" ]; then
    ok "create ui scaffold"
else
    bad "create ui scaffold"
fi
_pin9="$F/apps/verify/loop/ui-9/.gongsho-deployment.yaml"
if grep -q '^id: verify_loop_ui-9$' "$_pin9" && grep -q 'templateVersion: "1.0"' "$_pin9" && ! grep -q '^db:' "$_pin9"; then
    ok "create ui pin"
else
    bad "create ui pin"
fi
if grep -q -F "$F/bin/verify/loop/ui-9" "$F/proxy/deployments/verify_loop_ui-9"; then
    ok "create ui proxy"
else
    bad "create ui proxy"
fi
if grep -q -F "reload --config $F/proxy/Caddyfile" "$F/caddy.log"; then
    ok "create ui reload"
else
    bad "create ui reload"
fi

# --- create reload failure propagates (proxy already rendered) ---
export CADDY_STUB_FAIL=1
runv create verify/loop/ui-8 --template react-ui
unset CADDY_STUB_FAIL
if [ "$_rc" = "1" ] && printf '%s' "$_out" | grep -q -F "caddy reload failed" \
    && [ -f "$F/proxy/deployments/verify_loop_ui-8" ]; then
    ok "create reload failure"
else
    bad "create reload failure (exit $_rc: $_out)"
fi

# --- create API self-heal (tampered template + stub go) ---
# Tidy completes the tampered pins in place (no pin-fidelity verdict on
# this path per the staleness rule); the stub refuses migrate-shaped
# calls so the run then fails at the migrate step hermetically.
mkdir -p "$F/cstubbin"
cat >"$F/cstubbin/go" <<'SHEOF'
#!/bin/sh
set -eu
if [ "$1" = "list" ]; then echo "gongsho/stub/mod"; exit 0; fi
if [ "$1" = "run" ]; then
    case $2 in
        goa.design/*) mkdir -p gen/http; printf '{"openapi":"3.0.0"}' >gen/http/openapi3.json; exit 0 ;;
        *) echo "stub-go-create: migrate not emulated" >&2; exit 1 ;;
    esac
fi
if [ "$1" = "mod" ] && [ "$2" = "tidy" ]; then printf '\n// stub-tidy completion\n' >>go.mod; exit 0; fi
echo "stub-go-create: wrong call $*" >&2; exit 1
SHEOF
chmod +x "$F/cstubbin/go"
sed -i '/stretchr\/testify/d' "$F/templates/goa-api/app/go.mod"
_oldpath=$PATH
PATH="$F/cstubbin:$PATH"
runv create tamper/shop/api-9 --template goa-api
PATH=$_oldpath
unset _oldpath
if [ "$_rc" = "1" ] && printf '%s' "$_out" | grep -q -F "migrate step failed" \
    && grep -q -F "stub-tidy completion" "$F/apps/tamper/shop/api-9/go.mod"; then
    ok "create tampered pins self-heal"
else
    bad "create tampered pins self-heal (exit $_rc: $_out)"
fi

# --- refresh-spec positive ---
mkdir -p "$F/apps/acme/shop/api-1/gen"
printf '{"openapi":"3.0.0"}' >"$F/apps/acme/shop/api-1/gen/openapi.json"
expect_rc "refresh-spec ok" 0 refresh-spec acme_shop_ui-1 acme_shop_api-1
if cmp -s "$F/apps/acme/shop/api-1/gen/openapi.json" "$F/apps/acme/shop/ui-1/spec/acme_shop_api-1.openapi.json"; then
    ok "refresh-spec bytes"
else
    bad "refresh-spec bytes"
fi

# --- dev-up/dev-down UI (stub caddy) ---
mkdir -p "$F/run/t9/bundles/verify/loop/ui-9"
printf '<html></html>' >"$F/run/t9/bundles/verify/loop/ui-9/index.html"
expect_rc "dev-up ui ok" 0 dev-up t9 verify_loop_ui-9
_devf="$F/proxy/dev.d/t9-verify_loop_ui-9"
if grep -q -F 'handle_path /dev/t9/verify/loop/ui-9/*' "$_devf" \
    && grep -q -F "$F/run/t9/bundles/verify/loop/ui-9" "$_devf"; then
    ok "dev-up ui file"
else
    bad "dev-up ui file"
fi
if [ "$(grep -c -F 'reload --config' "$F/caddy.log")" = "2" ]; then
    ok "dev-up ui reload"
else
    bad "dev-up ui reload"
fi
expect_rc "dev-down ok" 0 dev-down t9
if [ ! -e "$_devf" ] && [ ! -e "$F/run/t9" ]; then
    ok "dev-down cleaned"
else
    bad "dev-down cleaned"
fi
expect_rc "dev-down idempotent" 0 dev-down t9
mkdir -p "$F/run/t9/bundles/verify/loop/ui-9"
printf '<html></html>' >"$F/run/t9/bundles/verify/loop/ui-9/index.html"
expect_rc "dev-up ui again" 0 dev-up t9 verify_loop_ui-9
expect_rc "dev-down keep-scratch" 0 dev-down --keep-scratch t9
if [ ! -e "$_devf" ] && [ -f "$F/run/t9/bundles/verify/loop/ui-9/index.html" ]; then
    ok "dev-down kept scratch"
else
    bad "dev-down kept scratch"
fi
rm -rf "$F/run/t9"

# --- check/status UI on crafted bundle ---
mkdir -p "$F/bin/verify/loop/ui-9/assets"
printf '<html>ui</html>' >"$F/bin/verify/loop/ui-9/index.html"
printf 'x' >"$F/bin/verify/loop/ui-9/assets/app-abc123.js"
printf '{\n  "apis": {}\n}\n' >"$F/bin/verify/loop/ui-9/gen-config.json"
expect_rc "check ui ok" 0 check verify_loop_ui-9
expect_rc_grep "status ui sections" 1 "bundle: present" status verify_loop_ui-9
runv status verify_loop_ui-9
if printf '%s' "$_out" | grep -q -F "gen-config: valid" \
    && printf '%s' "$_out" | grep -q -F "proxy: present" \
    && printf '%s' "$_out" | grep -q -F "route: unhealthy"; then
    ok "status ui route down"
else
    bad "status ui route down: $_out"
fi
printf '{"apis":{"zz_top_api-9":"/zz/top/api-9"}}' >"$F/bin/verify/loop/ui-9/gen-config.json"
expect_rc_grep "check ui stale gen-config" 1 "stale" check verify_loop_ui-9

# --- retire UI positive ---
expect_rc "retire ui ok" 0 retire verify_loop_ui-9
_arc=$(echo "$F"/apps/verify/loop/ui-9.retired-*)
if [ ! -e "$F/apps/verify/loop/ui-9" ] && [ -e "$_arc" ] \
    && [ ! -e "$F/proxy/deployments/verify_loop_ui-9" ] \
    && [ ! -e "$F/bin/verify/loop/ui-9" ]; then
    ok "retire ui archived"
else
    bad "retire ui archived"
fi

# --- start/status/check/restart/stop API via a python fake binary ---
if command -v python3 >/dev/null 2>&1; then
    mkdir -p "$F/bin/acme/shop/api-1" "$F/data/acme_shop_api-1"
    cat >"$F/bin/acme/shop/api-1/api" <<'PYEOF'
#!/usr/bin/env python3
import os, sys
from http.server import BaseHTTPRequestHandler
from socketserver import UnixStreamServer
req = ["SOCKET_PATH", "DB_PATH", "DEPLOYMENT_ID", "TEMPLATE", "TEMPLATE_VERSION"]
missing = [k for k in req if not os.environ.get(k)]
if missing:
    sys.stderr.write("missing: " + ",".join(missing) + "\n")
    sys.exit(1)
info = '{"id":"%s","template":"%s","templateVersion":"%s"}' % (
    os.environ["DEPLOYMENT_ID"], os.environ["TEMPLATE"], os.environ["TEMPLATE_VERSION"])
SPEC = b'{"openapi":"3.0.0"}'
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        code, body = 200, b'{}'
        if self.path == "/healthz":
            body = b'{"status":"ok"}'
        elif self.path == "/info":
            body = info.encode()
        elif self.path == "/openapi.json":
            body = SPEC
        else:
            code, body = 404, b'not found'
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a):
        pass
p = os.environ["SOCKET_PATH"]
if os.path.exists(p):
    os.unlink(p)
UnixStreamServer(p, H).serve_forever()
PYEOF
    chmod +x "$F/bin/acme/shop/api-1/api"
    : >"$F/data/acme_shop_api-1/app.db"
    cp "$R/templates/goa-api/app/.example.env" "$F/apps/acme/shop/api-1/.example.env"
    printf '{"openapi":"3.0.0"}' >"$F/apps/acme/shop/api-1/gen/openapi.json"
    expect_rc_grep "start api ok" 0 "healthy" start acme_shop_api-1
    expect_rc_grep "status api running" 1 "direct: healthy" status acme_shop_api-1
    expect_rc_grep "status api process" 1 "process: alive" status acme_shop_api-1
    expect_rc "check api ok" 0 check acme_shop_api-1
    expect_rc_grep "restart api ok" 0 "restarted" restart acme_shop_api-1
    expect_rc "stop api ok" 0 stop acme_shop_api-1
    expect_rc "check api stopped" 1 check acme_shop_api-1
else
    printf 'SKIP: no python3 for fake-binary cases\n'
fi

# --- migrate via a go-stub emulator (harness backup/restore logic only;
# real golang-migrate behavior is proven in scratch, not here) ---
if command -v python3 >/dev/null 2>&1; then
    mkdir -p "$F/stubbin" "$F/apps/acme/shop/api-1/migrations"
    cat >"$F/stubbin/go" <<'PYEOF'
#!/usr/bin/env python3
# Test double for `go`, limited to `run ... migrate@... -source .. -database .. <up|version>`.
import os, re, sqlite3, sys
args = sys.argv[1:]
def flag(name):
    for i, a in enumerate(args):
        if a == name and i + 1 < len(args):
            return args[i + 1]
    return None
src = flag("-source")
dburl = flag("-database")
cmd = args[-1] if args else ""
if not src or not src.startswith("file://") or not dburl or not dburl.startswith("sqlite://") or cmd not in ("up", "version"):
    sys.stderr.write("stub-go: unsupported invocation: %s\n" % " ".join(args))
    sys.exit(1)
migdir = src[len("file://"):]
dbpath = dburl[len("sqlite://"):]
os.makedirs(os.path.dirname(dbpath) or ".", exist_ok=True)
con = sqlite3.connect(dbpath)
con.execute("CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, dirty INTEGER NOT NULL)")
row = con.execute("SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1").fetchone()
cur = row[0] if row else 0
if cmd == "version":
    if not row:
        sys.stderr.write("stub-go: no version\n")
        sys.exit(1)
    print(cur)
    sys.exit(0)
files = sorted(f for f in os.listdir(migdir) if re.fullmatch(r"[0-9]+_.+\.up\.sql", f))
for f in files:
    ver = int(f.split("_", 1)[0])
    if ver <= cur:
        continue
    sql = open(os.path.join(migdir, f)).read()
    if "STUB-FAIL" in sql:
        sys.stderr.write("stub-go: migration %d failed\n" % ver)
        sys.exit(1)
    con.executescript(sql)
    con.execute("INSERT OR REPLACE INTO schema_migrations (version, dirty) VALUES (?, 0)", (ver,))
    con.commit()
    cur = ver
    print("%d/u applied" % ver)
PYEOF
    chmod +x "$F/stubbin/go"
    _oldpath=$PATH
    PATH="$F/stubbin:$PATH"
    _mig() { # run migrate under the stub, like runv
        _rc=0
        _out=$(sh "$R/tools/migrate" "$@" 2>&1) || _rc=$?
    }
    countbak() {
        _n=0
        for _b in "$F"/data/acme_shop_api-1/app.db.bak-*; do
            [ -e "$_b" ] || break
            _n=$((_n + 1))
        done
        printf '%s' "$_n"
        unset _b
    }
    rm -f "$F/data/acme_shop_api-1/app.db" "$F/data/acme_shop_api-1/app.db.bak-"*
    printf 'CREATE TABLE t1 (k TEXT);\n' >"$F/apps/acme/shop/api-1/migrations/0001_init.up.sql"
    _mig acme_shop_api-1
    if [ "$_rc" = "0" ] && printf '%s' "$_out" | grep -q -F "migrated to version 1" \
        && [ "$(countbak)" = "0" ]; then
        ok "migrate fresh no backup"
    else
        bad "migrate fresh no backup (exit $_rc: $_out)"
    fi
    printf 'CREATE TABLE t2 (k TEXT);\n' >"$F/apps/acme/shop/api-1/migrations/0002_x.up.sql"
    _mig acme_shop_api-1
    if [ "$_rc" = "0" ] && printf '%s' "$_out" | grep -q -F "migrated to version 2" \
        && [ "$(countbak)" = "1" ]; then
        ok "migrate existing backups"
    else
        bad "migrate existing backups (exit $_rc: $_out)"
    fi
    printf 'CREATE TABLE t3 (k TEXT);\n' >"$F/apps/acme/shop/api-1/migrations/0003_x.up.sql"
    _mig acme_shop_api-1 >/dev/null 2>&1
    printf 'CREATE TABLE t4 (k TEXT);\n' >"$F/apps/acme/shop/api-1/migrations/0004_x.up.sql"
    _mig acme_shop_api-1 >/dev/null 2>&1
    printf 'CREATE TABLE t5 (k TEXT);\n' >"$F/apps/acme/shop/api-1/migrations/0005_x.up.sql"
    _mig acme_shop_api-1 >/dev/null 2>&1
    if [ "$(countbak)" = "3" ]; then
        ok "migrate prunes to three"
    else
        bad "migrate prunes to three (count $(countbak))"
    fi
    printf '%s\n' '-- STUB-FAIL' 'CREATE TABLE t6 (k TEXT);' >"$F/apps/acme/shop/api-1/migrations/0006_x.up.sql"
    _mig acme_shop_api-1
    _dbv=$(python3 -c 'import sqlite3,sys; print(sqlite3.connect(sys.argv[1]).execute("select version from schema_migrations order by version desc limit 1").fetchone()[0])' "$F/data/acme_shop_api-1/app.db")
    if [ "$_rc" = "1" ] && printf '%s' "$_out" | grep -q -F "restored backup" \
        && [ "$_dbv" = "5" ]; then
        ok "migrate failure restores"
    else
        bad "migrate failure restores (exit $_rc version $_dbv: $_out)"
    fi
    rm "$F/apps/acme/shop/api-1/migrations/0006_x.up.sql"
    _mig --dev s9 acme_shop_api-1
    if [ "$_rc" = "0" ] && [ -f "$F/run/s9/data/acme/shop/api-1/app.db" ] \
        && [ -z "$(find "$F/run" -name '*.bak-*')" ]; then
        ok "migrate dev no backup"
    else
        bad "migrate dev no backup (exit $_rc: $_out)"
    fi
    mkdir -p "$F/tools/bin"
    cat >"$F/tools/bin/migrate" <<'PYEOF'
#!/usr/bin/env python3
# Fake prebuilt migrate: up prints a marker, version prints 9.
import sys
cmd = sys.argv[-1] if len(sys.argv) > 1 else ""
if cmd == "up":
    print("9/u fake-prebuilt")
elif cmd == "version":
    print("9")
else:
    sys.stderr.write("fake-prebuilt: wrong call\n")
    sys.exit(1)
PYEOF
    chmod +x "$F/tools/bin/migrate"
    printf 'v4.20.1\n' >"$F/tools/bin/migrate.version"
    mkdir -p "$F/failbin"
    printf '#!/bin/sh\necho "go-stub: should not run under prebuilt" >&2\nexit 1\n' >"$F/failbin/go"
    chmod +x "$F/failbin/go"
    PATH="$F/failbin:$PATH"
    _mig acme_shop_api-1
    if [ "$_rc" = "0" ] && printf '%s' "$_out" | grep -q -F "migrated to version 9"; then
        ok "migrate prefers prebuilt"
    else
        bad "migrate prefers prebuilt (exit $_rc: $_out)"
    fi
    PATH="$F/stubbin:$_oldpath"
    printf 'v0.0.0-stale\n' >"$F/tools/bin/migrate.version"
    _mig acme_shop_api-1
    if [ "$_rc" = "0" ] && printf '%s' "$_out" | grep -q -F "migrated to version 5"; then
        ok "migrate stale pin falls back"
    else
        bad "migrate stale pin falls back (exit $_rc: $_out)"
    fi
    rm "$F/tools/bin/migrate.version"
    _mig acme_shop_api-1
    if [ "$_rc" = "0" ] && printf '%s' "$_out" | grep -q -F "migrated to version 5"; then
        ok "migrate missing sidecar falls back"
    else
        bad "migrate missing sidecar falls back (exit $_rc: $_out)"
    fi
    rm -rf "$F/tools/bin" "$F/failbin"
    PATH=$_oldpath
    unset _oldpath
else
    printf 'SKIP: no python3 for migrate-stub cases\n'
fi

# --- cache-warm via a go stub (harness logic only; real compile proven in loop) ---
mkdir -p "$F/cwbin"
cat >"$F/cwbin/go" <<'SHEOF'
#!/bin/sh
set -eu
if [ "$1" = "mod" ]; then exit 0; fi
if [ "$1" = "list" ]; then echo "goa.design/goa/v3 v9.9.9-cwtest"; exit 0; fi
if [ "$1" = "install" ]; then
    case "$*" in
        *cmd/migrate*) mkdir -p "$GOBIN"; printf '#!/bin/sh\nexit 0\n' >"$GOBIN/migrate"; chmod +x "$GOBIN/migrate" ;;
    esac
    exit 0
fi
echo "stub-go-cachewarm: wrong call $*" >&2; exit 1
SHEOF
chmod +x "$F/cwbin/go"
cat >"$F/cwbin/npm" <<'SHEOF'
#!/bin/sh
set -eu
if [ "$1" = "install" ]; then
    _pp=""
    _prev=""
    for _a in "$@"; do
        if [ "$_prev" = "--prefix" ]; then _pp=$_a; fi
        _prev=$_a
    done
    [ -n "$_pp" ] || { echo "stub-npm: no prefix" >&2; exit 1; }
    mkdir -p "$_pp/node_modules/.bin"
    printf '#!/bin/sh\nexit 0\n' >"$_pp/node_modules/.bin/pnpm"
    chmod +x "$_pp/node_modules/.bin/pnpm"
    exit 0
fi
echo "stub-npm: wrong call $*" >&2; exit 1
SHEOF
chmod +x "$F/cwbin/npm"
_cw_oldpath=$PATH
PATH="$F/cwbin:$PATH"
runv cache-warm
if [ "$_rc" = "0" ] && [ -x "$F/tools/bin/migrate" ] \
    && [ "$(cat "$F/tools/bin/migrate.version")" = "v4.20.1" ] \
    && [ -x "$F/.cache/pnpm/node_modules/.bin/pnpm" ] \
    && [ "$(cat "$F/.cache/pnpm/pnpm.version")" = "9.15.9" ]; then
    ok "cache-warm builds migrate"
else
    bad "cache-warm builds migrate (exit $_rc: $_out)"
fi
runv cache-warm
if [ "$_rc" = "0" ] && printf '%s' "$_out" | grep -q -F "already built" \
    && printf '%s' "$_out" | grep -q -F "already provisioned"; then
    ok "cache-warm skips when warm"
else
    bad "cache-warm skips when warm (exit $_rc: $_out)"
fi
PATH=$_cw_oldpath
unset _cw_oldpath
rm -rf "$F/tools/bin" "$F/.cache"

# --- build --if-stale skips fresh outputs (stale paths proven in loop) ---
touch "$F/bin/acme/shop/api-1/api"
expect_rc_grep "build if-stale api fresh" 0 "up to date" build --if-stale acme_shop_api-1
mkdir -p "$F/bin/acme/shop/ui-1/assets"
printf '<html>ui</html>' >"$F/bin/acme/shop/ui-1/index.html"
printf 'x' >"$F/bin/acme/shop/ui-1/assets/app.js"
touch "$F/bin/acme/shop/ui-1/index.html" "$F/bin/acme/shop/ui-1/assets/app.js"
expect_rc_grep "build if-stale ui fresh" 0 "up to date" build --if-stale acme_shop_ui-1

# --- install dispatches to vendored pnpm (fake entry records calls) ---
mkdir -p "$F/.cache/pnpm/node_modules/.bin"
cat >"$F/.cache/pnpm/node_modules/.bin/pnpm" <<'SHEOF'
#!/bin/sh
printf '%s\n' "$*" >>"${PNPM_CALL_LOG:?}"
exit 0
SHEOF
chmod +x "$F/.cache/pnpm/node_modules/.bin/pnpm"
export PNPM_CALL_LOG="$F/pnpm.calls"
expect_rc "install ui ok" 0 install acme_shop_ui-1
if grep -q -F "install --store-dir $F/.cache/pnpm/store" "$F/pnpm.calls"; then
    ok "install uses shared store"
else
    bad "install uses shared store"
fi
runv pnpm import somewhere.lock
if [ "$_rc" = "0" ] && grep -qx -F "import somewhere.lock" "$F/pnpm.calls"; then
    ok "pnpm import passes through"
else
    bad "pnpm import passes through (exit $_rc)"
fi
_rrc=0
( cd "$R" && sh tools/install acme_shop_ui-1 ) >/dev/null 2>&1 || _rrc=$?
if [ "$_rrc" = "0" ]; then
    ok "install via relative path"
else
    bad "install via relative path (exit $_rrc)"
fi
unset _rrc
expect_rc_grep "install api refused" 1 "nothing to install" install acme_shop_api-1
rm "$F/.cache/pnpm/node_modules/.bin/pnpm"
expect_rc_grep "install unprovisioned" 1 "pnpm install failed" install acme_shop_ui-1
unset PNPM_CALL_LOG
rm -rf "$F/.cache"

# --- retire API positive (last: archives the api deployment) ---
mkdir -p "$F/proxy/deployments"
printf 'stub stanza\n' >"$F/proxy/deployments/acme_shop_api-1"
expect_rc "retire api ok" 0 retire acme_shop_api-1
_arc2=$(echo "$F"/apps/acme/shop/api-1.retired-*)
_arc3=$(echo "$F"/data/acme_shop_api-1.retired-*)
if [ ! -e "$F/apps/acme/shop/api-1" ] && [ -e "$_arc2" ] && [ -e "$_arc3" ] \
    && [ ! -e "$F/proxy/deployments/acme_shop_api-1" ] \
    && [ ! -e "$F/bin/acme/shop/api-1" ]; then
    ok "retire api archived"
else
    bad "retire api archived"
fi

# --- startup against an isolated fake root (per-deployment boot proven in loop) ---
if command -v python3 >/dev/null 2>&1; then
    _S2=$(mktemp -d)
    mkdir -p "$_S2/tools" "$_S2/templates/goa-api/app" "$_S2/templates/react-ui/app" "$_S2/templates/langchain-api/app" "$_S2/proxy"
    cp "$R/tools/lib.sh" "$_S2/tools/lib.sh"
    printf 'module stub\n\ngo 1.23\n' >"$_S2/templates/goa-api/app/go.mod"
    printf '' >"$_S2/templates/goa-api/app/go.sum"
    printf '{"name":"stub"}\n' >"$_S2/templates/react-ui/app/package.json"
    printf '# stub lock\n' >"$_S2/templates/react-ui/app/pnpm-lock.yaml"
    printf '{"name":"stub"}\n' >"$_S2/templates/langchain-api/app/package.json"
    printf '# stub lock\n' >"$_S2/templates/langchain-api/app/pnpm-lock.yaml"
    _o_repo=$GONGSHO_REPO; _o_home=$GONGSHO_HOME
    export GONGSHO_REPO=$_S2 GONGSHO_HOME=$_S2 GONGSHO_PORT=18281
    _oldpath2=$PATH; PATH="$F/cwbin:$PATH"
    python3 -m http.server 18281 --directory "$_S2" >/dev/null 2>&1 & _srv=$!
    sleep 1
    runv startup
    kill $_srv 2>/dev/null || true
    wait $_srv 2>/dev/null || true
    PATH=$_oldpath2; unset _oldpath2
    if [ "$_rc" = "0" ] && printf '%s' "$_out" | grep -q -F "no deployments to boot"; then
        ok "startup caddy-up no deployments"
    else
        bad "startup caddy-up no deployments (exit $_rc: $_out)"
    fi
    export GONGSHO_PORT=18282
    runv startup
    if [ "$_rc" = "1" ] && printf '%s' "$_out" | grep -q -F "did not come up"; then
        ok "startup caddy-down fails loud"
    else
        bad "startup caddy-down fails loud (exit $_rc: $_out)"
    fi
    export GONGSHO_REPO=$_o_repo GONGSHO_HOME=$_o_home
    unset GONGSHO_PORT
    unset _o_repo _o_home
    rm -rf "$_S2" "$F/cwbin"
else
    printf 'SKIP: no python3 for startup cases\n'
fi

# --- build UI positive: --base reaches vite intact (never after `--`) ---
# A recording pnpm stub stands in for the toolchain; its `exec vite` arm
# writes dist/index.html the way vite would, embedding the passed base.
# Fresh deployment: earlier cases leave snapshots behind and retire api-1.
_uid="acme_shop_ui-2"
_upath="acme/shop/ui-2"
_uapp="$F/apps/$_upath"
mkdir -p "$_uapp"
cat >"$_uapp/.gongsho-deployment.yaml" <<EOF
id: $_uid
path: $_upath
template: react-ui
templateVersion: "1.0"
vars: {}
created: "2026-11-11T12:00:00Z"
EOF
mkdir -p "$_uapp/spec" "$_uapp/node_modules/.bin" "$F/.cache/pnpm/node_modules/.bin"
printf '#!/bin/sh\nexit 0\n' >"$_uapp/node_modules/.bin/vite"
chmod +x "$_uapp/node_modules/.bin/vite"
cat >"$F/.cache/pnpm/node_modules/.bin/pnpm" <<'SHEOF'
#!/bin/sh
printf '%s\n' "$*" >>"${PNPM_CALL_LOG:?}"
if [ "$1" = "exec" ]; then
    shift
    if [ "$1" = "vite" ]; then
        shift
        _base=""
        for _a in "$@"; do
            case $_a in --base=*) _base=${_a#--base=};; esac
        done
        [ -n "$_base" ] || exit 1
        mkdir -p dist
        printf '<!doctype html><script src="%sassets/app.js"></script>\n' "$_base" >dist/index.html
        exit 0
    fi
    exit 0
fi
exit 0
SHEOF
chmod +x "$F/.cache/pnpm/node_modules/.bin/pnpm"
export PNPM_CALL_LOG="$F/pnpm.calls"
: >"$F/pnpm.calls"
runv build "$_uid"
if [ "$_rc" = "0" ]; then ok "build ui ok"; else bad "build ui ok (exit $_rc: $_out)"; fi
if grep -qx -F "exec vite build --base=/$_upath/" "$F/pnpm.calls"; then
    ok "build ui base reaches vite intact"
else
    bad "build ui base reaches vite intact ($(tr '\n' '|' <"$F/pnpm.calls"))"
fi
if grep -q -F "=\"/$_upath/assets/" "$F/bin/$_upath/index.html" 2>/dev/null; then
    ok "build ui bundle carries base"
else
    bad "build ui bundle carries base"
fi
unset PNPM_CALL_LOG _uapp _uid _upath
rm -rf "$F/.cache"

printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
[ "$fail" -eq 0 ]
