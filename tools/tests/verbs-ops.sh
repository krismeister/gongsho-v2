#!/bin/sh
# verbs-ops.sh — hermetic operational coverage: true positives via fixture
# trees plus a stub caddy, a python fake API binary, and a go-stub migrate
# emulator. Fake repo only; real toolchains never execute.
set -eu
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
unset GONGSHO_SCHEME GONGSHO_HOST GONGSHO_PORT GONGSHO_START_HEALTH_TIMEOUT GONGSHO_STOP_GRACE GONGSHO_MIGRATE_VERSION
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
cp -r "$R/templates/goa-api" "$R/templates/react-ui" "$F/templates/"
cat >"$F/apps/acme/shop/api-1/.gongsho-deployment.yaml" <<'EOF'
id: acme_shop_api-1
path: acme/shop/api-1
template: goa-api
templateVersion: "1.0"
vars: {}
db:
  type: SQLite
  path: data/acme/shop/api-1/app.db
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
export GONGSHO_REPO=$F
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

# --- create API pin-fidelity negative (tampered template + stub go) ---
# The stub stands in for go through scaffold: list prints a module path,
# run fakes goa gen output, tidy simulates completing incomplete pins.
mkdir -p "$F/cstubbin"
cat >"$F/cstubbin/go" <<'SHEOF'
#!/bin/sh
set -eu
if [ "$1" = "list" ]; then echo "gongsho/stub/mod"; exit 0; fi
if [ "$1" = "run" ]; then mkdir -p gen/http; printf '{"openapi":"3.0.0"}' >gen/http/openapi3.json; exit 0; fi
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
if [ "$_rc" = "1" ] && printf '%s' "$_out" | grep -q -F "not tidy-complete"; then
    ok "create tampered pins die"
else
    bad "create tampered pins die (exit $_rc: $_out)"
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
    mkdir -p "$F/bin/acme/shop/api-1" "$F/data/acme/shop/api-1"
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
    : >"$F/data/acme/shop/api-1/app.db"
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
        for _b in "$F"/data/acme/shop/api-1/app.db.bak-*; do
            [ -e "$_b" ] || break
            _n=$((_n + 1))
        done
        printf '%s' "$_n"
        unset _b
    }
    rm -f "$F/data/acme/shop/api-1/app.db" "$F/data/acme/shop/api-1/app.db.bak-"*
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
    _dbv=$(python3 -c 'import sqlite3,sys; print(sqlite3.connect(sys.argv[1]).execute("select version from schema_migrations order by version desc limit 1").fetchone()[0])' "$F/data/acme/shop/api-1/app.db")
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
    PATH=$_oldpath
    unset _oldpath
else
    printf 'SKIP: no python3 for migrate-stub cases\n'
fi

# --- retire API positive (last: archives the api deployment) ---
mkdir -p "$F/proxy/deployments"
printf 'stub stanza\n' >"$F/proxy/deployments/acme_shop_api-1"
expect_rc "retire api ok" 0 retire acme_shop_api-1
_arc2=$(echo "$F"/apps/acme/shop/api-1.retired-*)
_arc3=$(echo "$F"/data/acme/shop/api-1.retired-*)
if [ ! -e "$F/apps/acme/shop/api-1" ] && [ -e "$_arc2" ] && [ -e "$_arc3" ] \
    && [ ! -e "$F/proxy/deployments/acme_shop_api-1" ] \
    && [ ! -e "$F/bin/acme/shop/api-1" ]; then
    ok "retire api archived"
else
    bad "retire api archived"
fi

printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
[ "$fail" -eq 0 ]
