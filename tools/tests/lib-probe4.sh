#!/bin/sh
# Probe4: render_dev_stanza derivation + need_yq guard.
set -eu
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
export VERB=probe4
F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/tools" "$F/templates/goa-api/config/caddy" "$F/templates/react-ui/config/caddy" \
  "$F/apps/acme/shop/api-1" "$F/apps/acme/shop/ui-1" "$F/proxy/deployments"
cp $R/tools/lib.sh $F/tools/lib.sh
cp $R/templates/goa-api/.gongsho-tpl.yaml $F/templates/goa-api/
cp $R/templates/react-ui/.gongsho-tpl.yaml $F/templates/react-ui/
cp $R/templates/goa-api/config/caddy/stanza $F/templates/goa-api/config/caddy/
cp $R/templates/react-ui/config/caddy/stanza $F/templates/react-ui/config/caddy/
printf 'id: acme_shop_api-1\npath: acme/shop/api-1\ntemplate: goa-api\ntemplateVersion: "1.0"\nvars: {}\ndb:\n  type: SQLite\n  path: data/acme/shop/api-1/app.db\ncreated: "2026-11-11T12:00:00Z"\n' > $F/apps/acme/shop/api-1/.gongsho-deployment.yaml
printf 'id: acme_shop_ui-1\npath: acme/shop/ui-1\ntemplate: react-ui\ntemplateVersion: "1.0"\nvars: {}\ncreated: "2026-11-11T12:00:00Z"\n' > $F/apps/acme/shop/ui-1/.gongsho-deployment.yaml
export GONGSHO_REPO=$F
. "$F/tools/lib.sh"

pass=0; fail=0
ok() { pass=$((pass+1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1"; }
expect_ok() {
  label=$1; shift
  if ("$@" >/dev/null 2>&1); then ok "$label"; else bad "$label (exited nonzero)"; fi
}
expect_fail() {
  label=$1; shift
  if ("$@" >/dev/null 2>&1); then bad "$label (should have failed)"; else ok "$label"; fi
}

# --- render stable, then derive dev ---
render_stanza goa-api acme_shop_api-1 acme/shop/api-1 "$F/proxy/deployments/acme_shop_api-1"
render_stanza react-ui acme_shop_ui-1 acme/shop/ui-1 "$F/proxy/deployments/acme_shop_ui-1"
expect_ok "dev api derives" render_dev_stanza a3f9 acme_shop_api-1 "$F/dev-api"
expect_ok "dev prefix api" grep -q -F 'handle_path /dev/a3f9/acme/shop/api-1/*' "$F/dev-api"
expect_ok "dev socket api" grep -q -F 'acme_shop_api-1.dev-a3f9.sock' "$F/dev-api"
expect_fail "no stable socket left" grep -q -F 'unix//'"$F"'/proxy/sockets/acme_shop_api-1.sock' "$F/dev-api"
expect_ok "dev ui derives" render_dev_stanza a3f9 acme_shop_ui-1 "$F/dev-ui"
expect_ok "dev prefix ui" grep -q -F 'handle_path /dev/a3f9/acme/shop/ui-1/*' "$F/dev-ui"
expect_ok "dev root ui" grep -q -F "$F/run/a3f9/bundles/acme/shop/ui-1" "$F/dev-ui"
expect_fail "no stable root left" grep -q -F "$F/bin/acme/shop/ui-1" "$F/dev-ui"
expect_ok "dev comments preserved" grep -q -F '${VAR} form' "$F/dev-ui"

# --- tamper cases ---
expect_fail "dev missing stable" render_dev_stanza a3f9 acme_shop_api-9 "$F/dev-x"
cp "$F/proxy/deployments/acme_shop_api-1" "$F/proxy/deployments/acme_shop_api-1.good"
printf 'handle_path /WRONG/* {\n}\n' > "$F/proxy/deployments/acme_shop_api-1"
expect_fail "dev tampered prefix" render_dev_stanza a3f9 acme_shop_api-1 "$F/dev-x"
cp "$F/proxy/deployments/acme_shop_api-1.good" "$F/proxy/deployments/acme_shop_api-1"
cp "$F/proxy/deployments/acme_shop_ui-1" "$F/dev-ui-as-api"
cp "$F/dev-ui-as-api" "$F/proxy/deployments/acme_shop_api-1"
expect_fail "dev wrong shape (ui file, api pin)" render_dev_stanza a3f9 acme_shop_api-1 "$F/dev-x"
cp "$F/proxy/deployments/acme_shop_api-1.good" "$F/proxy/deployments/acme_shop_api-1"

# --- need_yq guard ---
expect_ok "need_yq mikefarah" need_yq
mkdir -p "$F/fakebin" "$F/emptybin"
printf '#!/bin/sh\necho "yq 4.4.5"; echo "jq-1.8.2"\n' > "$F/fakebin/yq"
chmod +x "$F/fakebin/yq"
expect_fail "need_yq rejects kislyuk" env PATH="$F/fakebin:/usr/bin:/bin" GONGSHO_REPO="$F" sh -c 'VERB=t; . "$0" >/dev/null 2>&1; need_yq' "$F/tools/lib.sh"
# NOTE (landing): the original used bare `sh` here, which env cannot find on
# an empty PATH (exit 127), so the case passed without ever running need_yq.
# Absolute shell path makes it test what it claims.
_SH=$(command -v sh)
expect_fail "need_yq rejects missing" env PATH="$F/emptybin" GONGSHO_REPO="$F" "$_SH" -c 'VERB=t; . "$0" >/dev/null 2>&1; need_yq' "$F/tools/lib.sh"

rm -rf "$F"
printf '%s\npass=%d fail=%d\n' "---" "$pass" "$fail"
[ "$fail" -eq 0 ]
