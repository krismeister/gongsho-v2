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
# goa-api manifest WITHOUT owned: stanza recreation keys off the template
# name, never the owned list (a future owned-gate must break these tests).
printf 'name: goa-api\nversion: "1.0"\nvars:\n  - id\n' > $F/templates/goa-api/.gongsho-tpl.yaml
cp $R/templates/react-ui/.gongsho-tpl.yaml $F/templates/react-ui/
cp $R/templates/goa-api/config/caddy/stanza $F/templates/goa-api/config/caddy/
cp $R/templates/react-ui/config/caddy/stanza $F/templates/react-ui/config/caddy/
printf 'id: acme_shop_api-1\npath: acme/shop/api-1\ntemplate: goa-api\ntemplateVersion: "1.0"\nvars: {}\ndb:\n  type: SQLite\n  path: acme_shop_api-1/app.db\ncreated: "2026-11-11T12:00:00Z"\n' > $F/apps/acme/shop/api-1/.gongsho-deployment.yaml
printf 'id: acme_shop_ui-1\npath: acme/shop/ui-1\ntemplate: react-ui\ntemplateVersion: "1.0"\nvars: {}\ncreated: "2026-11-11T12:00:00Z"\n' > $F/apps/acme/shop/ui-1/.gongsho-deployment.yaml
mkdir -p "$F/apps/badtpl/shop/api-9"
printf 'id: badtpl_shop_api-9\npath: badtpl/shop/api-9\ntemplate: nope-tpl\ntemplateVersion: "1.0"\nvars: {}\ndb:\n  type: SQLite\n  path: badtpl_shop_api-9/app.db\ncreated: "2026-11-11T12:00:00Z"\n' > $F/apps/badtpl/shop/api-9/.gongsho-deployment.yaml
export GONGSHO_REPO=$F GONGSHO_HOME=$F
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

# --- derived state heals: tampered or missing stable files re-render ---
expect_fail "dev unknown deployment" render_dev_stanza a3f9 acme_shop_api-9 "$F/dev-x"
printf 'handle_path /WRONG/* {\n}\n' > "$F/proxy/deployments/acme_shop_api-1"
expect_ok "dev heals tampered prefix" render_dev_stanza a3f9 acme_shop_api-1 "$F/dev-x"
expect_ok "stable healed prefix" grep -q -F 'handle_path /acme/shop/api-1/*' "$F/proxy/deployments/acme_shop_api-1"
cp "$F/proxy/deployments/acme_shop_ui-1" "$F/proxy/deployments/acme_shop_api-1"
expect_ok "dev heals wrong shape" render_dev_stanza a3f9 acme_shop_api-1 "$F/dev-x"
expect_ok "stable healed shape" grep -q -F 'unix//'"$F"'/proxy/sockets/acme_shop_api-1.sock' "$F/proxy/deployments/acme_shop_api-1"
rm -f "$F/proxy/deployments/acme_shop_api-1"
expect_ok "dev renders missing stable" render_dev_stanza a3f9 acme_shop_api-1 "$F/dev-x"
expect_ok "stable re-rendered" grep -q -F 'handle_path /acme/shop/api-1/*' "$F/proxy/deployments/acme_shop_api-1"

# --- ensure_proxy_file ---
rm -f "$F/proxy/deployments/acme_shop_ui-1"
expect_ok "ensure renders missing" ensure_proxy_file acme_shop_ui-1
expect_ok "ensure content" grep -q -F "$F/bin/acme/shop/ui-1" "$F/proxy/deployments/acme_shop_ui-1"
printf 'tampered\n' > "$F/proxy/deployments/acme_shop_ui-1"
expect_ok "ensure heals tampered" ensure_proxy_file acme_shop_ui-1
expect_ok "ensure healed content" grep -q -F 'handle_path /acme/shop/ui-1/*' "$F/proxy/deployments/acme_shop_ui-1"
expect_fail "ensure unknown deployment" ensure_proxy_file acme_shop_api-9
expect_ok "ensure ignores owned (goa manifest stripped)" ensure_proxy_file acme_shop_api-1
expect_fail "ensure refuses unknown template" ensure_proxy_file badtpl_shop_api-9

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
