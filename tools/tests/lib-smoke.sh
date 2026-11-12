#!/bin/sh
# Smoke test for tools/lib.sh. Touches nothing in the real repo: all
# fixtures live under a mktemp scratch dir (cleaned by trap).
# Run directly: sh tools/tests/lib-smoke.sh
# Run everything: sh tools/tests/run.sh
set -u

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REAL=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/smoke"
export GONGSHO_REPO="$REAL"
export VERB=libtest
. "$REAL/tools/lib.sh"

# --- derivations -----------------------------------------------------------
[ "$(id_to_path acme_shop_api-1)" = "acme/shop/api-1" ] && ok id_to_path || bad id_to_path
[ "$(path_to_id acme/shop/api-1)" = "acme_shop_api-1" ] && ok path_to_id || bad path_to_id
[ "$(id_slug acme_shop_api-1)" = "ACME_SHOP_API_1" ] && ok id_slug || bad id_slug

# --- validators: accept ------------------------------------------------------
( validate_id acme_shop_api-1 ) 2>/dev/null && ok validate_id-ok || bad validate_id-ok
( validate_path acme/shop/api-1 ) 2>/dev/null && ok validate_path-ok || bad validate_path-ok
( validate_session a3f9 ) 2>/dev/null && ok validate_session-ok || bad validate_session-ok
( validate_template_name goa-api ) 2>/dev/null && ok validate_tpl-ok || bad validate_tpl-ok

# --- validators: reject with exit 2 ------------------------------------------
t2() { # <desc> <fn> <arg>
    ( "$2" "$3" ) >/dev/null 2>&1
    code=$?
    if [ "$code" -eq 2 ]; then ok "$1"; else bad "$1 (exit $code)"; fi
}
t2 validate_id-rejects-path validate_id acme/shop/api-1
t2 validate_id-rejects-short validate_id acme_shop
t2 validate_id-rejects-long validate_id a_b_c_d
t2 validate_id-rejects-upper validate_id ACME_shop_api
t2 validate_id-rejects-dev validate_id dev_shop_api
t2 validate_id-rejects-empty validate_id ""
t2 validate_path-rejects-id validate_path acme_shop_api-1
t2 validate_path-rejects-short validate_path acme/shop
t2 validate_path-rejects-dev validate_path dev/shop/api
t2 validate_session-rejects-upper validate_session A3F9
t2 validate_session-rejects-slash validate_session a/b
t2 validate_session-rejects-empty validate_session ""
t2 validate_tpl-rejects-bogus validate_template_name nope
( validate_id acme/shop/api-1 ) 2>&1 | grep -q 'got path-like' && ok id-hint || bad id-hint
( validate_path acme_shop_api-1 ) 2>&1 | grep -q 'got ID-like' && ok path-hint || bad path-hint

# --- path builders -------------------------------------------------------------
[ "$(app_dir acme_shop_api-1)" = "$REAL/apps/acme/shop/api-1" ] && ok app_dir || bad app_dir
[ "$(socket_path acme_shop_api-1)" = "$REAL/proxy/sockets/acme_shop_api-1.sock" ] && ok socket || bad socket
[ "$(pidfile_path acme_shop_api-1)" = "$REAL/proxy/sockets/acme_shop_api-1.pid" ] && ok pidfile || bad pidfile
[ "$(dev_proxy_file a3f9 acme_shop_api-1)" = "$REAL/proxy/dev.d/a3f9-acme_shop_api-1" ] && ok devproxy || bad devproxy
[ "$(dev_socket_path a3f9 acme_shop_api-1)" = "$REAL/proxy/sockets/acme_shop_api-1.dev-a3f9.sock" ] && ok devsock || bad devsock
[ "$(dev_bundle_dir a3f9 acme_shop_ui-1)" = "$REAL/run/a3f9/bundles/acme/shop/ui-1" ] && ok devbundle || bad devbundle
[ "$(dev_db_path a3f9 acme_shop_api-1)" = "$REAL/run/a3f9/data/acme/shop/api-1/app.db" ] && ok devdb || bad devdb
[ "$(artifacts_dir a3f9)" = "$REAL/run/a3f9/artifacts" ] && ok artifacts || bad artifacts

# --- atomic writes ---------------------------------------------------------------
T=$(tmp_in_dir $SCRATCH/smoke)
printf 'hello' >"$T"
atomic_mv "$T" $SCRATCH/smoke/sub/final.txt
[ "$(cat $SCRATCH/smoke/sub/final.txt)" = "hello" ] && ok atomic || bad atomic

# --- time/session/hash -------------------------------------------------------------
case $(mint_session) in ????????) ok mint-len ;; *) bad mint-len ;; esac
mint_session | grep -q '^[0-9a-f][0-9a-f]*$' && ok mint-hex || bad mint-hex
printf 'x' | sha256sum | cut -d' ' -f1 | grep -q . || true
printf 'abc' > $SCRATCH/smoke/h.txt
[ "$(sha256_file $SCRATCH/smoke/h.txt)" = "$(sha256sum $SCRATCH/smoke/h.txt | cut -d' ' -f1)" ] && ok sha || bad sha
utc_now | grep -q '^[0-9][0-9]*-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$' && ok utc || bad utc
ts_short | grep -q '^[0-9][0-9]*T[0-9][0-9]*Z$' && ok ts || bad ts

# --- json_equal --------------------------------------------------------------------
printf '{"status":"ok"}' > $SCRATCH/smoke/j1
printf '{\n  "status": "ok"\n}\n' > $SCRATCH/smoke/j2
printf '{"status":"bad"}' > $SCRATCH/smoke/j3
printf 'not json' > $SCRATCH/smoke/j4
json_equal $SCRATCH/smoke/j1 $SCRATCH/smoke/j2 && ok json-eq || bad json-eq
json_equal $SCRATCH/smoke/j1 $SCRATCH/smoke/j3 || ok json-neq || bad json-neq
json_equal $SCRATCH/smoke/j1 $SCRATCH/smoke/j4 || ok json-invalid || bad json-invalid

# --- stanza rendering (real templates -> scratch) ---------------------------------
render_stanza goa-api acme_shop_api-1 acme/shop/api-1 $SCRATCH/smoke/goa.stanza
grep -q "reverse_proxy unix//$REAL/proxy/sockets/acme_shop_api-1.sock" $SCRATCH/smoke/goa.stanza && ok goa-sock || bad goa-sock
grep -q 'handle_path /acme/shop/api-1/\*' $SCRATCH/smoke/goa.stanza && ok goa-path || bad goa-path
_has_placeholders $SCRATCH/smoke/goa.stanza && bad goa-leftover || ok goa-leftover
render_stanza react-ui acme_shop_ui-1 acme/shop/ui-1 $SCRATCH/smoke/ui.stanza
grep -q "root \* $REAL/bin/acme/shop/ui-1" $SCRATCH/smoke/ui.stanza && ok ui-root || bad ui-root
_has_placeholders $SCRATCH/smoke/ui.stanza && bad ui-leftover || ok ui-leftover
grep -q -F '${VAR}' $SCRATCH/smoke/ui.stanza && ok ui-doc-preserved || bad ui-doc-preserved
printf 'x {{ID}}\n' > $SCRATCH/smoke/ph1.txt
_has_placeholders $SCRATCH/smoke/ph1.txt && ok ph-catches-known || bad ph-catches-known
printf '# doc uses ${VAR} form\n' > $SCRATCH/smoke/ph2.txt
_has_placeholders $SCRATCH/smoke/ph2.txt && bad ph-allows-doc-comment || ok ph-allows-doc-comment
printf 'x {{FOO}}\n' > $SCRATCH/smoke/ph3.txt
_has_placeholders $SCRATCH/smoke/ph3.txt && ok ph-catches-unknown || bad ph-catches-unknown

# --- template kind ------------------------------------------------------------------
[ "$(template_kind goa-api)" = "api" ] && ok kind-api || bad kind-api
[ "$(template_kind react-ui)" = "ui" ] && ok kind-ui || bad kind-ui
( template_kind nope ) >/dev/null 2>&1; [ $? -eq 2 ] && ok kind-bogus || bad kind-bogus

# --- transport failures ---------------------------------------------------------------
[ "$(direct_get $SCRATCH/smoke/nope.sock /healthz $SCRATCH/smoke/b)" = "000" ] && ok direct-000 || bad direct-000
[ "$(http_get http://127.0.0.1:9/ $SCRATCH/smoke/b)" = "000" ] && ok http-000 || bad http-000
wait_direct_health $SCRATCH/smoke/nope.sock "$REAL/templates/goa-api/config/health.json" 1
[ $? -eq 1 ] && ok wait-timeout || bad wait-timeout

# --- stop_pidfile -----------------------------------------------------------------------
echo "=== stop (missing) ==="
stop_pidfile $SCRATCH/smoke/nope.pid 1 >/dev/null && ok stop-missing || bad stop-missing
echo 99999999 > $SCRATCH/smoke/stale.pid
stop_pidfile $SCRATCH/smoke/stale.pid 1 >/dev/null
[ $? -eq 0 ] && [ ! -f $SCRATCH/smoke/stale.pid ] && ok stop-stale || bad stop-stale
sleep 30 &
SLEEPPID=$!
printf '%s\n' "$SLEEPPID" > $SCRATCH/smoke/live.pid
stop_pidfile $SCRATCH/smoke/live.pid 2 >/dev/null
if [ $? -eq 0 ] && [ ! -f $SCRATCH/smoke/live.pid ] && ! kill -0 "$SLEEPPID" 2>/dev/null; then
    ok stop-live
else
    bad stop-live; kill -KILL "$SLEEPPID" 2>/dev/null || true
fi

# --- fake repo: pins, gen-config, env ------------------------------------------------------
FR=$SCRATCH/fakerepo
mkdir -p "$FR/tools" "$FR/templates/goa-api" "$FR/templates/react-ui"
mkdir -p "$FR/apps/acme/shop/api-1/spec" "$FR/apps/acme/shop/api-2" "$FR/apps/acme/shop/ui-1/spec"
cp "$REAL/tools/lib.sh" "$FR/tools/lib.sh"
cp "$REAL/templates/goa-api/.gongsho-tpl.yaml" "$FR/templates/goa-api/.gongsho-tpl.yaml"
cp "$REAL/templates/react-ui/.gongsho-tpl.yaml" "$FR/templates/react-ui/.gongsho-tpl.yaml"
mkdir -p "$FR/templates/goa-api/config/caddy" "$FR/templates/react-ui/config/caddy"
cp "$REAL/templates/goa-api/config/caddy/stanza" "$FR/templates/goa-api/config/caddy/stanza"
cp "$REAL/templates/react-ui/config/caddy/stanza" "$FR/templates/react-ui/config/caddy/stanza"
cat > "$FR/apps/acme/shop/api-1/.gongsho-deployment.yaml" <<'EOF'
id: acme_shop_api-1
path: acme/shop/api-1
template: goa-api
templateVersion: "1.0"
vars: {}
db:
  type: SQLite
  path: data/acme/shop/api-1/app.db
created: "2026-11-12T00:00:00Z"
EOF
cat > "$FR/apps/acme/shop/api-2/.gongsho-deployment.yaml" <<'EOF'
id: acme_shop_api-2
path: acme/shop/api-2
template: goa-api
templateVersion: "1.0"
vars: {}
db:
  type: SQLite
  path: data/acme/shop/api-2/app.db
created: "2026-11-12T00:00:00Z"
EOF
cat > "$FR/apps/acme/shop/ui-1/.gongsho-deployment.yaml" <<'EOF'
id: acme_shop_ui-1
path: acme/shop/ui-1
template: react-ui
templateVersion: "1.0"
vars: {}
created: "2026-11-12T00:00:00Z"
EOF
export GONGSHO_REPO="$FR"
# re-resolve REPO_ROOT the way a fresh source would
REPO_ROOT="$FR"

( validate_pin acme_shop_api-1 ) 2>/dev/null && ok pin-api || bad pin-api
( validate_pin acme_shop_ui-1 ) 2>/dev/null && ok pin-ui || bad pin-ui
( validate_pin acme_shop_nope-9 ) >/dev/null 2>&1; [ $? -eq 1 ] && ok pin-missing || bad pin-missing
( validate_pin 'not-an-id' ) >/dev/null 2>&1; [ $? -eq 2 ] && ok pin-malformed-id || bad pin-malformed-id
# pin negatives: mismatched path, api-without-db, ui-with-db
mkdir -p "$FR/apps/acme/shop/bad-1" "$FR/apps/acme/shop/bad-2" "$FR/apps/acme/shop/bad-3"
sed 's|path: acme/shop/api-1|path: acme/shop/other|' "$FR/apps/acme/shop/api-1/.gongsho-deployment.yaml" \
    | sed 's|id: acme_shop_api-1|id: acme_shop_bad-1|; s|data/acme/shop/api-1|data/acme/shop/bad-1|' \
    > "$FR/apps/acme/shop/bad-1/.gongsho-deployment.yaml"
( validate_pin acme_shop_bad-1 ) >/dev/null 2>&1; [ $? -eq 1 ] && ok pin-mismatch || bad pin-mismatch
sed 's|id: acme_shop_api-1|id: acme_shop_bad-2|; s|path: acme/shop/api-1|path: acme/shop/bad-2|; /^db:$/,/^  path: .*$/d' \
    "$FR/apps/acme/shop/api-1/.gongsho-deployment.yaml" > "$FR/apps/acme/shop/bad-2/.gongsho-deployment.yaml"
( validate_pin acme_shop_bad-2 ) >/dev/null 2>&1; [ $? -eq 1 ] && ok pin-api-nodb || bad pin-api-nodb
sed 's|id: acme_shop_ui-1|id: acme_shop_bad-3|; s|path: acme/shop/ui-1|path: acme/shop/bad-3|' \
    "$FR/apps/acme/shop/ui-1/.gongsho-deployment.yaml" > "$FR/apps/acme/shop/bad-3/.gongsho-deployment.yaml"
printf 'db:\n  type: SQLite\n  path: data/acme/shop/bad-3/app.db\n' >> "$FR/apps/acme/shop/bad-3/.gongsho-deployment.yaml"
( validate_pin acme_shop_bad-3 ) >/dev/null 2>&1; [ $? -eq 1 ] && ok pin-ui-withdb || bad pin-ui-withdb
[ "$(pin_template acme_shop_api-1)" = "goa-api" ] && ok pin-tpl || bad pin-tpl
[ "$(pin_db_path acme_shop_api-1)" = "data/acme/shop/api-1/app.db" ] && ok pin-db || bad pin-db
[ -z "$(pin_db_path acme_shop_ui-1)" ] && ok pin-nodb || bad pin-nodb

# gen-config: two snapshots, reverse-alpha creation order
printf '{"openapi":"3.0.0"}' > "$FR/apps/acme/shop/ui-1/spec/acme_shop_api-2.openapi.json"
printf '{"openapi":"3.0.0"}' > "$FR/apps/acme/shop/ui-1/spec/acme_shop_api-1.openapi.json"
write_gen_config "$FR/apps/acme/shop/ui-1/public/gen-config.json" "$FR/apps/acme/shop/ui-1" ""
cat > $SCRATCH/smoke/gen.want <<'EOF'
{
  "apis": {
    "acme_shop_api-1": "/acme/shop/api-1",
    "acme_shop_api-2": "/acme/shop/api-2"
  }
}
EOF
cmp $SCRATCH/smoke/gen.want "$FR/apps/acme/shop/ui-1/public/gen-config.json" && ok gen-stable || bad gen-stable
write_gen_config $SCRATCH/smoke/gen-dev.json "$FR/apps/acme/shop/ui-1" "/dev/a3f9"
grep -q '"/dev/a3f9/acme/shop/api-1"' $SCRATCH/smoke/gen-dev.json && ok gen-dev || bad gen-dev
mkdir -p "$FR/apps/acme/shop/empty/spec"
write_gen_config $SCRATCH/smoke/gen-empty.json "$FR/apps/acme/shop/empty" ""
cmp $SCRATCH/smoke/gen-empty.json "$REAL/templates/react-ui/app/public/gen-config.json" && ok gen-empty || bad gen-empty
printf '{}' > "$FR/apps/acme/shop/ui-1/spec/acme_shop_gone-9.openapi.json"
( write_gen_config $SCRATCH/smoke/gen-x.json "$FR/apps/acme/shop/ui-1" "" ) >/dev/null 2>&1
[ $? -eq 1 ] && ok gen-dangling || bad gen-dangling
rm "$FR/apps/acme/shop/ui-1/spec/acme_shop_gone-9.openapi.json"
printf '{}' > "$FR/apps/acme/shop/ui-1/spec/BADNAME.openapi.json"
( write_gen_config $SCRATCH/smoke/gen-x.json "$FR/apps/acme/shop/ui-1" "" ) >/dev/null 2>&1
[ $? -eq 1 ] && ok gen-malformed || bad gen-malformed
rm "$FR/apps/acme/shop/ui-1/spec/BADNAME.openapi.json"
# failing gen-config calls leave no temp files behind and write no dest
mkdir -p $SCRATCH/leak-tmp $SCRATCH/leak-dest
_oldtmp=${TMPDIR:-}
TMPDIR=$SCRATCH/leak-tmp; export TMPDIR
printf '{}' > "$FR/apps/acme/shop/ui-1/spec/acme_shop_gone-9.openapi.json"
( write_gen_config $SCRATCH/leak-dest/gen.json "$FR/apps/acme/shop/ui-1" "" ) >/dev/null 2>&1
_leak_rc=$?
rm -f "$FR/apps/acme/shop/ui-1/spec/acme_shop_gone-9.openapi.json"
if [ "$_leak_rc" -eq 1 ] && [ -z "$(ls -A $SCRATCH/leak-tmp)" ] && [ -z "$(ls -A $SCRATCH/leak-dest)" ]; then
    ok gc-fail-clean
else
    bad gc-fail-clean
fi
if [ -n "$_oldtmp" ]; then TMPDIR=$_oldtmp; export TMPDIR; else unset TMPDIR; fi
unset _oldtmp _leak_rc

# env: .env creation + tunable + injected override
printf 'LOG_LEVEL=debug\nSOCKET_PATH=should-be-overridden\n' > "$FR/apps/acme/shop/api-1/.example.env"
source_app_env "$FR/apps/acme/shop/api-1" >/dev/null
[ -f "$FR/apps/acme/shop/api-1/.env" ] && ok env-created || bad env-created
export_injected acme_shop_api-1 /sock/x.sock /data/x.db
[ "$LOG_LEVEL" = "debug" ] && ok env-tunable || bad env-tunable
[ "$SOCKET_PATH" = "/sock/x.sock" ] && [ "$DB_PATH" = "/data/x.db" ] && ok env-injected || bad env-injected
[ "$DEPLOYMENT_ID" = "acme_shop_api-1" ] && [ "$TEMPLATE" = "goa-api" ] && [ "$TEMPLATE_VERSION" = "1.0" ] && ok env-identity || bad env-identity

# dev derivation: render stable stanzas, derive, byte-compare
render_stanza goa-api acme_shop_api-1 acme/shop/api-1 "$FR/proxy/deployments/acme_shop_api-1"
render_stanza react-ui acme_shop_ui-1 acme/shop/ui-1 "$FR/proxy/deployments/acme_shop_ui-1"
render_dev_stanza a3f9 acme_shop_api-1 "$FR/proxy/dev.d/a3f9-acme_shop_api-1"
{
    printf 'handle_path /dev/a3f9/acme/shop/api-1/* {\n'
    printf '\treverse_proxy unix//%s/proxy/sockets/acme_shop_api-1.dev-a3f9.sock {\n' "$FR"
    printf '\t\theader_up Host localhost\n'
    printf '\t}\n'
    printf '}\n'
} > $SCRATCH/smoke/devapi.want
cmp $SCRATCH/smoke/devapi.want "$FR/proxy/dev.d/a3f9-acme_shop_api-1" && ok dev-api-bytes || bad dev-api-bytes
render_dev_stanza a3f9 acme_shop_ui-1 "$FR/proxy/dev.d/a3f9-acme_shop_ui-1"
{
    printf '# Gongsho react-ui proxy stanza template (owned: proxy-stanza).\n'
    printf '# Rendered per deployment by the harness. Variables use ${VAR} form:\n'
    printf '#   acme/shop/ui-1  slash path of the deployment, e.g. acme/shop/ui-1\n'
    printf '#   %s  absolute path of the repo checkout\n' "$FR"
    printf '# Shape follows docs/phase-1/proxy.md verbatim (handle_path strips the\n'
    printf '# prefix, so inner matchers see bundle-relative paths).\n'
    printf 'handle_path /dev/a3f9/acme/shop/ui-1/* {\n'
    printf '    root * %s/run/a3f9/bundles/acme/shop/ui-1\n' "$FR"
    printf '    route {\n'
    printf '        try_files {path} /index.html\n'
    printf '        header /index.html Cache-Control "public, max-age=0, must-revalidate"\n'
    printf '    }\n'
    printf '    header /assets/* Cache-Control "public, max-age=31536000, immutable"\n'
    printf '    file_server\n'
    printf '}\n'
} > $SCRATCH/smoke/devui.want
cmp $SCRATCH/smoke/devui.want "$FR/proxy/dev.d/a3f9-acme_shop_ui-1" && ok dev-ui-bytes || bad dev-ui-bytes
# dev derivation asserts: tampered stable files and missing file all fail loud
cp "$FR/proxy/deployments/acme_shop_api-1" $SCRATCH/smoke/stable-api.bak
sed -i 's|handle_path|handle|' "$FR/proxy/deployments/acme_shop_api-1"
( render_dev_stanza a3f9 acme_shop_api-1 $SCRATCH/smoke/dev-t1 ) >/dev/null 2>&1
[ $? -eq 1 ] && ok dev-tamper-prefix || bad dev-tamper-prefix
cp $SCRATCH/smoke/stable-api.bak "$FR/proxy/deployments/acme_shop_api-1"
sed -i 's|acme_shop_api-1\.sock|other_api-9.sock|' "$FR/proxy/deployments/acme_shop_api-1"
( render_dev_stanza a3f9 acme_shop_api-1 $SCRATCH/smoke/dev-t2 ) >/dev/null 2>&1
[ $? -eq 1 ] && ok dev-tamper-sock || bad dev-tamper-sock
cp $SCRATCH/smoke/stable-api.bak "$FR/proxy/deployments/acme_shop_api-1"
cp "$FR/proxy/deployments/acme_shop_ui-1" $SCRATCH/smoke/stable-ui.bak
sed -i '/^    root \*/d' "$FR/proxy/deployments/acme_shop_ui-1"
( render_dev_stanza a3f9 acme_shop_ui-1 $SCRATCH/smoke/dev-t3 ) >/dev/null 2>&1
[ $? -eq 1 ] && ok dev-tamper-root || bad dev-tamper-root
cp $SCRATCH/smoke/stable-ui.bak "$FR/proxy/deployments/acme_shop_ui-1"
( render_dev_stanza a3f9 acme_shop_api-2 $SCRATCH/smoke/dev-t4 ) >/dev/null 2>&1
[ $? -eq 1 ] && ok dev-missing-stable || bad dev-missing-stable
cp "$FR/proxy/deployments/acme_shop_ui-1" "$FR/proxy/deployments/acme_shop_api-2"
( render_dev_stanza a3f9 acme_shop_api-2 $SCRATCH/smoke/dev-t5 ) >/dev/null 2>&1
[ $? -eq 1 ] && ok dev-wrong-shape || bad dev-wrong-shape
rm -f "$FR/proxy/deployments/acme_shop_api-2"

# render refuses an unknown placeholder dialect in a directive line
cp "$FR/templates/goa-api/config/caddy/stanza" $SCRATCH/smoke/stanza.bak
printf '  x {{FOO}}\n' >> "$FR/templates/goa-api/config/caddy/stanza"
( render_stanza goa-api acme_shop_api-1 acme/shop/api-1 $SCRATCH/smoke/fo.out ) >/dev/null 2>&1
[ $? -eq 1 ] && [ ! -f $SCRATCH/smoke/fo.out ] && ok render-refuses-unknown || bad render-refuses-unknown
cp $SCRATCH/smoke/stanza.bak "$FR/templates/goa-api/config/caddy/stanza"

# need_yq flavor guard: wrong flavor and missing binary both die naming go-yq
mkdir -p $SCRATCH/fakebin $SCRATCH/emptybin
printf '#!/bin/sh\necho "yq 4.4.5"\n' > $SCRATCH/fakebin/yq
chmod +x $SCRATCH/fakebin/yq
( PATH="$SCRATCH/fakebin:$PATH"; pin_get acme_shop_api-1 .id ) >$SCRATCH/smoke/yq1.out 2>$SCRATCH/smoke/yq1.err
[ $? -eq 1 ] && grep -q 'go-yq' $SCRATCH/smoke/yq1.err && ok needyq-flavor || bad needyq-flavor
( PATH="$SCRATCH/emptybin"; pin_get acme_shop_api-1 .id ) >$SCRATCH/smoke/yq2.out 2>$SCRATCH/smoke/yq2.err
[ $? -eq 1 ] && grep -q 'go-yq' $SCRATCH/smoke/yq2.err && ok needyq-missing || bad needyq-missing

# log/die/usage plumbing
[ "$(log hello)" = "[libtest] hello" ] && ok log-prefix || bad log-prefix
( die boom ) 2>$SCRATCH/smoke/die.txt; [ $? -eq 1 ] && grep -q '^\[libtest\] error: boom$' $SCRATCH/smoke/die.txt && ok die-plumb || bad die-plumb
( usage nope ) 2>$SCRATCH/smoke/usage.txt; [ $? -eq 2 ] && grep -q "tools/libtest --help" $SCRATCH/smoke/usage.txt && ok usage-plumb || bad usage-plumb
( need_cmd definitely-not-a-command-xyz ) 2>/dev/null; [ $? -eq 1 ] && ok needcmd || bad needcmd

printf '\npass=%s fail=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
