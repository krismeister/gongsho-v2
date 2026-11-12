#!/bin/sh
# verbs-cli.sh — CLI contract for all 15 verbs: help, usage errors, unknown
# deployments, hermetic state failures. Fake repo only; no toolchains run.
set -eu
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
unset GONGSHO_SCHEME GONGSHO_HOST GONGSHO_PORT GONGSHO_START_HEALTH_TIMEOUT GONGSHO_STOP_GRACE GONGSHO_MIGRATE_VERSION
F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/tools" "$F/templates/goa-api" "$F/templates/react-ui" \
  "$F/apps/acme/shop/api-1" "$F/apps/acme/shop/ui-1"
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
cat >"$F/apps/acme/shop/ui-1/.gongsho-deployment.yaml" <<'EOF'
id: acme_shop_ui-1
path: acme/shop/ui-1
template: react-ui
templateVersion: "1.0"
vars: {}
created: "2026-11-11T12:00:00Z"
EOF
export GONGSHO_REPO=$F

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

# --- help ---
for _s in create build deploy retire start stop restart status dev-up dev-down check e2e refresh-spec migrate template-check; do
    expect_rc_grep "$_s --help" 0 "usage: tools/$_s" "$_s" --help
done

# --- usage ---
expect_rc "create no args" 2 create
expect_rc "create two paths" 2 create a/b/c d/e/f --template goa-api
expect_rc "create missing template" 2 create acme/shop/new-9
expect_rc "create unknown template" 2 create acme/shop/new-9 --template nope
expect_rc "create id-like path" 2 create acme_shop_new-9 --template goa-api
expect_rc "create short path" 2 create acme/shop
expect_rc "create unknown flag" 2 create acme/shop/new-9 --template goa-api --bogus
for _s in build deploy retire start stop restart status check; do
    expect_rc "$_s no args" 2 "$_s"
    expect_rc "$_s two args" 2 "$_s" a_b_c d_e_f
    expect_rc "$_s malformed" 2 "$_s" nope
done
expect_rc "dev-up no args" 2 dev-up
expect_rc "dev-up session only" 2 dev-up s9
expect_rc "dev-up bad session" 2 dev-up 'bad sess' acme_shop_api-1
expect_rc "dev-down no args" 2 dev-down
expect_rc "dev-down bad session" 2 dev-down 'bad sess'
expect_rc "dev-down bad flag" 2 dev-down --bogus s9
expect_rc "e2e no args" 2 e2e
expect_rc "refresh-spec no args" 2 refresh-spec
expect_rc "refresh-spec one arg" 2 refresh-spec a_b_c
expect_rc "refresh-spec three args" 2 refresh-spec a_b_c d_e_f g_h_i
expect_rc "migrate no args" 2 migrate
expect_rc "migrate bare --dev" 2 migrate --dev
expect_rc "migrate bad session" 2 migrate --dev 'bad sess' acme_shop_api-1
expect_rc "migrate bad flag" 2 migrate --bogus acme_shop_api-1
expect_rc "template-check no args" 2 template-check
expect_rc "template-check unknown" 2 template-check nope
expect_rc "template-check two args" 2 template-check goa-api react-ui

# --- unknown deployments ---
for _s in build deploy retire start stop restart status check migrate; do
    expect_rc "$_s unknown id" 1 "$_s" acme_shop_nope-9
done
expect_rc "e2e unknown id" 1 e2e acme_shop_nope-9
expect_rc "dev-up unknown id" 1 dev-up s9 acme_shop_nope-9
expect_rc "refresh-spec unknown ui" 1 refresh-spec acme_shop_nope-9 acme_shop_api-1
expect_rc "refresh-spec unknown api" 1 refresh-spec acme_shop_ui-1 acme_shop_nope-9

# --- hermetic state cases (ordered: binary crafted midway) ---
expect_rc_grep "start ui refused" 1 "no process" start acme_shop_ui-1
expect_rc_grep "stop ui refused" 1 "no process" stop acme_shop_ui-1
expect_rc_grep "restart ui refused" 1 "nothing to restart" restart acme_shop_ui-1
expect_rc_grep "check api no binary" 1 "no binary" check acme_shop_api-1
expect_rc_grep "start api no binary" 1 "no binary" start acme_shop_api-1
expect_rc_grep "dev-up api no binary" 1 "no binary" dev-up s9 acme_shop_api-1
expect_rc_grep "dev-up ui no bundle" 1 "no dev bundle" dev-up s9 acme_shop_ui-1
expect_rc_grep "dev-down unknown session" 0 "no dev routes" dev-down s9
expect_rc_grep "migrate ui refused" 1 "no database" migrate acme_shop_ui-1
expect_rc_grep "migrate no migrations dir" 1 "no migrations dir" migrate acme_shop_api-1
mkdir -p "$F/apps/acme/shop/api-1/migrations"
expect_rc_grep "migrate no up files" 1 "no *.up.sql" migrate acme_shop_api-1
expect_rc_grep "refresh-spec api as ui" 1 "not a UI" refresh-spec acme_shop_api-1 acme_shop_api-1
expect_rc_grep "refresh-spec ui as api" 1 "not an API" refresh-spec acme_shop_ui-1 acme_shop_ui-1
expect_rc_grep "refresh-spec missing source" 1 "no generated spec" refresh-spec acme_shop_ui-1 acme_shop_api-1
expect_rc_grep "check ui no bundle" 1 "no bundle" check acme_shop_ui-1
expect_rc_grep "status ui missing" 1 "bundle: missing" status acme_shop_ui-1
expect_rc_grep "status api down" 1 "process: down" status acme_shop_api-1
expect_rc_grep "create existing dir" 1 "already exists" create acme/shop/api-1 --template goa-api
mkdir -p "$F/apps/tplcheck/tmp/goa-api"
expect_rc_grep "template-check residue" 1 "residue" template-check goa-api
expect_rc "e2e multi with unknown" 1 e2e acme_shop_api-1 acme_shop_nope-9
if [ ! -e "$F/run" ]; then ok "e2e validates before side effects"; else bad "e2e validates before side effects"; fi

mkdir -p "$F/bin/acme/shop/api-1"
printf '#!/bin/sh\nexit 0\n' >"$F/bin/acme/shop/api-1/api"
chmod +x "$F/bin/acme/shop/api-1/api"
expect_rc_grep "start api no db" 1 "no database" start acme_shop_api-1
expect_rc_grep "check api not running" 1 "not running" check acme_shop_api-1
expect_rc_grep "stop api not running" 0 "not running" stop acme_shop_api-1

mkdir -p "$F/apps/acme/shop/api-1/gen" "$F/apps/acme/shop/ui-1/spec"
printf '{"openapi":"3.0.0","v":2}' >"$F/apps/acme/shop/api-1/gen/openapi.json"
printf '{"openapi":"3.0.0","v":1}' >"$F/apps/acme/shop/ui-1/spec/acme_shop_api-1.openapi.json"
expect_rc_grep "build ui drift" 1 "snapshot drift" build acme_shop_ui-1
printf '{"openapi":"3.0.0","v":1}' >"$F/apps/acme/shop/ui-1/spec/acme_shop_gone-9.openapi.json"
rm "$F/apps/acme/shop/ui-1/spec/acme_shop_api-1.openapi.json"
expect_rc_grep "build ui dangling" 1 "dangling snapshot" build acme_shop_ui-1
rm "$F/apps/acme/shop/ui-1/spec/acme_shop_gone-9.openapi.json"
expect_rc_grep "build ui no node_modules" 1 "node_modules" build acme_shop_ui-1

printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
[ "$fail" -eq 0 ]
