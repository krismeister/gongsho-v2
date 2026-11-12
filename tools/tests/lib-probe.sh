#!/bin/sh
# Probe lib.sh pure functions. Exits nonzero on any failure.
set -eu
TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$TEST_DIR/../.." && pwd)
export VERB=probe GONGSHO_REPO=$R
. "$GONGSHO_REPO/tools/lib.sh"

pass=0; fail=0
ok() { pass=$((pass+1)); printf 'ok: %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1"; }
expect_eq() { # <label> <got> <want>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi
}
expect_ok() { # <label> <cmd...>
  label=$1; shift
  if "$@" >/dev/null 2>&1; then ok "$label"; else bad "$label (exited nonzero)"; fi
}
expect_fail() { # <label> <cmd...> — must exit nonzero (run in subshell: dies exit)
  label=$1; shift
  if ("$@" >/dev/null 2>&1); then bad "$label (should have failed)"; else ok "$label"; fi
}

# --- derivations ---
expect_eq "id_to_path" "$(id_to_path acme_shop_api-1)" "acme/shop/api-1"
expect_eq "path_to_id" "$(path_to_id acme/shop/api-1)" "acme_shop_api-1"
expect_eq "id_slug" "$(id_slug acme_shop_api-1)" "ACME_SHOP_API_1"

# --- validation: accept ---
expect_ok "validate_id good" validate_id acme_shop_api-1
expect_ok "validate_path good" validate_path acme/shop/api-1
expect_ok "validate_session good" validate_session a3f9
expect_ok "validate_template goa" validate_template_name goa-api
expect_ok "validate_template react" validate_template_name react-ui

# --- validation: reject ---
expect_fail "reject 2-seg id" validate_id acme_shop
expect_fail "reject 4-seg id" validate_id a_b_c_d
expect_fail "reject empty seg" validate_id acme__api-1
expect_fail "reject uppercase" validate_id Acme_shop_api-1
expect_fail "reject underscore-in-seg path" validate_path acme_shop/api-1
expect_fail "reject dev team id" validate_id dev_shop_api-1
expect_fail "reject dev team path" validate_path dev/shop/api-1
expect_fail "reject path-as-id" validate_id acme/shop/api-1
expect_fail "reject id-as-path" validate_path acme_shop_api-1
expect_fail "reject trailing slash" validate_path acme/shop/
expect_fail "reject leading slash" validate_path /acme/shop/api-1
expect_fail "reject empty session" validate_session ""
expect_fail "reject bad session" validate_session 'a3 f9'
expect_fail "reject unknown template" validate_template_name nope-x

# --- path builders ---
R=$GONGSHO_REPO
expect_eq "app_dir" "$(app_dir acme_shop_api-1)" "$R/apps/acme/shop/api-1"
expect_eq "bin_dir" "$(bin_dir acme_shop_api-1)" "$R/bin/acme/shop/api-1"
expect_eq "data_dir" "$(data_dir acme_shop_api-1)" "$R/data/acme/shop/api-1"
expect_eq "proxy_file" "$(proxy_file acme_shop_api-1)" "$R/proxy/deployments/acme_shop_api-1"
expect_eq "socket" "$(socket_path acme_shop_api-1)" "$R/proxy/sockets/acme_shop_api-1.sock"
expect_eq "pidfile" "$(pidfile_path acme_shop_api-1)" "$R/proxy/sockets/acme_shop_api-1.pid"
expect_eq "dev_proxy" "$(dev_proxy_file a3f9 acme_shop_api-1)" "$R/proxy/dev.d/a3f9-acme_shop_api-1"
expect_eq "dev_socket" "$(dev_socket_path a3f9 acme_shop_api-1)" "$R/proxy/sockets/acme_shop_api-1.dev-a3f9.sock"
expect_eq "dev_bundle" "$(dev_bundle_dir a3f9 acme_shop_ui-1)" "$R/run/a3f9/bundles/acme/shop/ui-1"
expect_eq "dev_db" "$(dev_db_path a3f9 acme_shop_api-1)" "$R/run/a3f9/data/acme/shop/api-1/app.db"
expect_eq "pin_file" "$(pin_file acme_shop_api-1)" "$R/apps/acme/shop/api-1/.gongsho-deployment.yaml"

# --- stanza rendering (stable) ---
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
render_stanza goa-api acme_shop_api-1 acme/shop/api-1 "$T/api"
expect_ok "goa stanza has socket" grep -q -F "unix//$R/proxy/sockets/acme_shop_api-1.sock" "$T/api"
expect_ok "goa stanza has path" grep -q -F "handle_path /acme/shop/api-1/*" "$T/api"
render_stanza react-ui acme_shop_ui-1 acme/shop/ui-1 "$T/ui"
expect_ok "react stanza root" grep -q -F "root * $R/bin/acme/shop/ui-1" "$T/ui"
expect_ok "react stanza has path" grep -q -F "handle_path /acme/shop/ui-1/*" "$T/ui"

# --- gen-config: empty matches scaffold placeholder byte-for-byte ---
mkdir -p "$T/uidir/spec"
write_gen_config "$T/uidir/gen-config.json" "$T/uidir" ""
if cmp -s "$T/uidir/gen-config.json" "$R/templates/react-ui/app/public/gen-config.json"; then
  ok "empty gen-config byte-identical to placeholder"
else
  bad "empty gen-config differs from placeholder"; diff "$T/uidir/gen-config.json" "$R/templates/react-ui/app/public/gen-config.json" || true
fi

# --- pidfile helpers ---
expect_ok "live pid (self)" pid_is_live "$$"
expect_fail "dead pid" pid_is_live 99999999
expect_fail "non-numeric pid" pid_is_live abc
printf '  4242 \n' >"$T/x.pid"
expect_eq "read_pidfile strips ws" "$(read_pidfile "$T/x.pid")" "4242"
expect_eq "read_pidfile missing" "$(read_pidfile "$T/nope.pid")" ""
stop_pidfile "$T/nope.pid" 3  # no pidfile -> ok
printf '99999998' >"$T/stale.pid"
expect_ok "stop stale pidfile" stop_pidfile "$T/stale.pid" 1
[ -f "$T/stale.pid" ] && bad "stale pidfile not removed" || ok "stale pidfile removed"

# --- json_equal / sha ---
printf '{"a":1}' >"$T/j1"; printf '{"a": 1}' >"$T/j2"; printf '{"a":2}' >"$T/j3"
expect_ok "json_equal same" json_equal "$T/j1" "$T/j2"
expect_fail "json_equal diff" json_equal "$T/j1" "$T/j3"
expect_eq "sha256" "$(sha256_file "$T/j1")" "$(sha256sum "$T/j1" | cut -d' ' -f1)"

# --- sessions/time ---
S1=$(mint_session); S2=$(mint_session)
case $S1 in
????????) ok "mint_session 8-hex" ;;
*) bad "mint_session shape: $S1" ;;
esac
[ "$S1" != "$S2" ] && ok "mint_session unique" || bad "mint_session collision"
case $(utc_now) in ????-??-??T??:??:??Z) ok "utc_now RFC3339";; *) bad "utc_now shape";; esac

rm -rf "$T"
printf '%s\npass=%d fail=%d\n' '---' "$pass" "$fail"
[ "$fail" -eq 0 ]
