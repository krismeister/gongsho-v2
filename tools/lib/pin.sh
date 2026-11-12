# lib/pin.sh — deployment pins and template manifests (YAML reads via yq).
# Sourced via tools/lib.sh; never sourced or run alone.
#
# yq dialect: mikefarah yq v4 (`yq eval`, `-r`, `-e`, `-o=json`) as cited
# in the phase-plan Sources. need_yq() refuses any other flavor.

need_yq() { # refuse to run YAML reads under any yq but mikefarah's
    command -v yq >/dev/null 2>&1 || die "missing required command 'yq' (install it with: sudo pacman -S go-yq)"
    _L_yv=$(yq --version 2>&1 || true)
    printf '%s' "$_L_yv" | grep -qi mikefarah || \
        die "unsupported yq flavor (have: ${_L_yv:-unknown}; want mikefarah yq - install it with: sudo pacman -S go-yq)"
}

pin_file() { printf '%s/apps/%s/.gongsho-deployment.yaml' "$REPO_ROOT" "$(id_to_path "$1")"; } # <id>
deployment_exists() { [ -f "$(pin_file "$1")" ]; }

pin_get() { # <id> <yq-expr> — raw value from the deployment pin
    need_yq
    _L_pin=$(pin_file "$1")
    deployment_exists "$1" || die "unknown deployment '$1' (no $_L_pin; create it with: tools/create $(id_to_path "$1") --template <name>)"
    _L_out=$(yq eval -r "$2" "$_L_pin" 2>&1) || die "cannot parse $_L_pin: $_L_out"
    printf '%s' "$_L_out"
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
    _L_out=$(yq eval -r "$2" "$REPO_ROOT/templates/$1/.gongsho-tpl.yaml" 2>&1) || die "cannot parse template manifest for '$1': $_L_out"
    printf '%s' "$_L_out"
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
    _L_pin=$(pin_file "$1")
    deployment_exists "$1" || die "unknown deployment '$1' (no $_L_pin)"
    yq eval '.' "$_L_pin" >/dev/null 2>&1 || die "cannot parse $_L_pin"
    [ "$(pin_get "$1" '.id')" = "$1" ] || die "pin id mismatch in $_L_pin (want '$1')"
    [ "$(pin_get "$1" '.path')" = "$(id_to_path "$1")" ] || die "pin path disagrees with id in $_L_pin"
    _L_t=$(pin_template "$1")
    validate_template_name "$_L_t"
    pin_has "$1" '.templateVersion' || die "pin misses templateVersion in $_L_pin"
    pin_has "$1" '.vars' || die "pin misses vars in $_L_pin"
    pin_has "$1" '.created' || die "pin misses created in $_L_pin"
    _L_kind=$(template_kind "$_L_t")
    if [ "$_L_kind" = "api" ]; then
        [ "$(pin_get "$1" '.db.type // ""')" = "SQLite" ] || die "API pin misses db.type SQLite in $_L_pin"
        [ -n "$(pin_db_path "$1")" ] || die "API pin misses db.path in $_L_pin"
    else
        if pin_has "$1" '.db'; then die "UI pin must not carry db in $_L_pin"; fi
    fi
}
