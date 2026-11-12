#!/bin/sh
# Probe lib.sh pin/env/gen-config/supervisor paths against a fake repo.
set -eu
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
export VERB=probe2
F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/tools" "$F/templates/goa-api" "$F/templates/react-ui" \
  "$F/apps/acme/shop/api-1" "$F/apps/acme/shop/api-2" "$F/apps/acme/shop/ui-1"
cp "$R/tools/lib.sh" "$F/tools/lib.sh"
cp "$R/templates/goa-api/.gongsho-tpl.yaml" "$F/templates/goa-api/"
cp "$R/templates/react-ui/.gongsho-tpl.yaml" "$F/templates/react-ui/"
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
cat >"$F/apps/acme/shop/api-2/.gongsho-deployment.yaml" <<'EOF'
id: acme_shop_api-2
path: acme/shop/api-2
template: goa-api
templateVersion: "1.0"
vars: {}
db:
  type: SQLite
  path: data/acme/shop/api-2/app.db
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
. "$F/tools/lib.sh"

pass=0; fail=0
ok() { pass=$((pass+1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1"; }
expect_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi
}
expect_ok() {
  label=$1; shift
  if ("$@" >/dev/null 2>&1); then ok "$label"; else bad "$label (exited nonzero)"; fi
}
expect_fail() {
  label=$1; shift
  if ("$@" >/dev/null 2>&1); then bad "$label (should have failed)"; else ok "$label"; fi
}

# --- pins ---
expect_ok "validate_pin api" validate_pin acme_shop_api-1
expect_ok "validate_pin ui" validate_pin acme_shop_ui-1
expect_eq "pin_db_path api" "$(pin_db_path acme_shop_api-1)" "data/acme/shop/api-1/app.db"
expect_eq "pin_db_path ui empty" "$(pin_db_path acme_shop_ui-1)" ""
expect_eq "template_kind api" "$(template_kind goa-api)" "api"
expect_eq "template_kind ui" "$(template_kind react-ui)" "ui"
expect_ok "exists true" deployment_exists acme_shop_api-1
expect_fail "exists false" deployment_exists acme_shop_nope-9
expect_ok "pin_has vars" pin_has acme_shop_api-1 '.vars'
expect_fail "pin_has missing" pin_has acme_shop_ui-1 '.db'

# --- pin negatives (each in a scratch copy so the good pins stay intact) ---
T=$F/apps/acme/shop/api-1/.gongsho-deployment.yaml
cp "$T" "$T.good"
yq eval '.id = "WRONG"' -i "$T"; expect_fail "pin id mismatch" validate_pin acme_shop_api-1; cp "$T.good" "$T"
yq eval '.path = "acme/shop/other"' -i "$T"; expect_fail "pin path mismatch" validate_pin acme_shop_api-1; cp "$T.good" "$T"
yq eval 'del(.db)' -i "$T"; expect_fail "api pin missing db" validate_pin acme_shop_api-1; cp "$T.good" "$T"
yq eval '.template = "nope-x"' -i "$T"; expect_fail "pin bad template" validate_pin acme_shop_api-1; cp "$T.good" "$T"
U=$F/apps/acme/shop/ui-1/.gongsho-deployment.yaml
cp "$U" "$U.good"
yq eval '.db = {"type": "SQLite", "path": "x"}' -i "$U"; expect_fail "ui pin with db" validate_pin acme_shop_ui-1; cp "$U.good" "$U"

# --- gen-config non-empty (stable + dev prefix) ---
mkdir -p "$F/apps/acme/shop/ui-1/spec"
printf '{"openapi":"x"}' >"$F/apps/acme/shop/ui-1/spec/acme_shop_api-2.openapi.json"
printf '{"openapi":"x"}' >"$F/apps/acme/shop/ui-1/spec/acme_shop_api-1.openapi.json"
write_gen_config "$F/stable.json" "$F/apps/acme/shop/ui-1" ""
expect_eq "gen-config stable" "$(cat "$F/stable.json")" "$(printf '{\n  "apis": {\n    "acme_shop_api-1": "/acme/shop/api-1",\n    "acme_shop_api-2": "/acme/shop/api-2"\n  }\n}\n')"
write_gen_config "$F/dev.json" "$F/apps/acme/shop/ui-1" "/dev/a3f9"
expect_ok "gen-config dev prefix" grep -q -F '"/dev/a3f9/acme/shop/api-1"' "$F/dev.json"
printf '{"openapi":"x"}' >"$F/apps/acme/shop/ui-1/spec/acme_shop_gone-9.openapi.json"
expect_fail "gen-config dangling snapshot" write_gen_config "$F/dangle.json" "$F/apps/acme/shop/ui-1" ""
rm "$F/apps/acme/shop/ui-1/spec/acme_shop_gone-9.openapi.json"
printf '{"openapi":"x"}' >"$F/apps/acme/shop/ui-1/spec/acme_shop_ui-1.openapi.json"
expect_fail "gen-config non-API snapshot" write_gen_config "$F/nonapi.json" "$F/apps/acme/shop/ui-1" ""
rm "$F/apps/acme/shop/ui-1/spec/acme_shop_ui-1.openapi.json"
printf '{"openapi":"x"}' >"$F/apps/acme/shop/ui-1/spec/NOTANID.openapi.json"
expect_fail "gen-config malformed snapshot id" write_gen_config "$F/malformed.json" "$F/apps/acme/shop/ui-1" ""
rm "$F/apps/acme/shop/ui-1/spec/NOTANID.openapi.json"

# --- app env + injected ---
mkdir -p "$F/envapp"
cp "$R/templates/goa-api/app/.example.env" "$F/envapp/.example.env"
unset LOG_LEVEL
source_app_env "$F/envapp"
expect_eq "env ensure creates .env" "$(test -f "$F/envapp/.env" && echo yes)" "yes"
expect_eq "env sources tunable" "${LOG_LEVEL:-unset}" "info"
printf 'LOG_LEVEL=debug\n' >"$F/envapp/.env"
unset LOG_LEVEL
source_app_env "$F/envapp"
expect_eq "env keeps existing .env" "${LOG_LEVEL:-unset}" "debug"
export_injected acme_shop_api-1 "$F/x.sock" data/acme/shop/api-1/app.db
expect_eq "injected socket" "$SOCKET_PATH" "$F/x.sock"
expect_eq "injected db" "$DB_PATH" "data/acme/shop/api-1/app.db"
expect_eq "injected id" "$DEPLOYMENT_ID" "acme_shop_api-1"
expect_eq "injected template" "$TEMPLATE" "goa-api"
expect_eq "injected version" "$TEMPLATE_VERSION" "1.0"

# --- supervisor: stop a live process ---
sleep 30 & _sp=$!
printf '%s' "$_sp" >"$F/live.pid"
expect_ok "stop live pid" stop_pidfile "$F/live.pid" 3
pid_is_live "$_sp" && { bad "victim still alive"; kill -KILL "$_sp" 2>/dev/null || true; } || ok "victim reaped"
[ -f "$F/live.pid" ] && bad "pidfile not removed" || ok "pidfile removed"

# --- direct_get on dead socket -> 000, fast ---
rm -f "$F/dead.sock"
_code=$(direct_get "$F/dead.sock" /healthz "$F/out")
expect_eq "direct_get dead socket" "$_code" "000"

# --- wait_direct_health negatives ---
expect_fail "health missing spec" wait_direct_health "$F/dead.sock" "$F/nope.json" 1
printf '{"path":"/healthz","status":200,"body":{"status":"ok"}}' >"$F/h.json"
expect_fail "health dead socket times out" wait_direct_health "$F/dead.sock" "$F/h.json" 1

# --- wait_direct_health positive (python unix-socket server, if available) ---
if command -v python3 >/dev/null 2>&1; then
  python3 - "$F/ok.sock" <<'PYEOF' & _srv=$!
import sys, json, os
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import UnixStreamServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'{"status": "ok"}'
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass
p = sys.argv[1]
if os.path.exists(p): os.unlink(p)
UnixStreamServer(p, H).serve_forever()
PYEOF
  sleep 1
  expect_ok "health positive over socket" wait_direct_health "$F/ok.sock" "$F/h.json" 5
  kill "$_srv" 2>/dev/null || true
  wait "$_srv" 2>/dev/null || true
else
  printf 'SKIP: no python3 for positive health test\n'
fi

rm -rf "$F"
printf '%s\npass=%d fail=%d\n' "---" "$pass" "$fail"
[ "$fail" -eq 0 ]
