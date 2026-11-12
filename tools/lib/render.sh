# lib/render.sh — proxy-stanza rendering and gen-config.json writing.
# Sourced via tools/lib.sh; never sourced or run alone.
#
# The two landed stanzas use different placeholder dialects (goa-api: {{X}},
# react-ui: ${X}); render the superset so both dialects resolve, then refuse
# to emit a file with leftovers (an undeclared template input).
#
# Stable stanzas render once at create time. dev-up never re-renders from
# the template: it derives the dev stanza from the already-rendered stable
# proxy file via render_dev_stanza below.
#
# gen-config.json maps each consumed API (<api-id> from spec/*.openapi.json)
# to its same-origin path. <prefix> is "" for stable bundles,
# "/dev/<session>" for dev bundles. Byte-stable: sorted keys, and the empty
# map matches the scaffold placeholder exactly.

_sed_escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }
_bre_escape() { printf '%s' "$1" | sed -e 's/[][\\.*^$|]/\\&/g'; }

_has_placeholders() { # <file> — 0 when any {{ or ${ placeholder remains in directive lines
    # Full-line comments are not directives: the react-ui stanza documents
    # its own `${VAR}` syntax in a comment, which must pass, while any
    # placeholder-shaped text in a directive line (known or unknown) fails.
    grep -v '^[[:space:]]*#' "$1" | grep -q -F -e '{{' -e '${'
}

render_stanza() { # <template> <id> <path> <dest> — render owned stanza to dest
    _L_src=$(stanza_src "$1")
    [ -f "$_L_src" ] || die "template '$1' has no proxy stanza source ($_L_src)"
    _L_tmp=$(tmp_in_dir "$(dirname -- "$4")")
    sed -e "s|{{ID}}|$(_sed_escape "$2")|g" \
        -e "s|{{PATH}}|$(_sed_escape "$3")|g" \
        -e "s|{{REPO}}|$(_sed_escape "$REPO_ROOT")|g" \
        -e "s|\${ID}|$(_sed_escape "$2")|g" \
        -e "s|\${PATH}|$(_sed_escape "$3")|g" \
        -e "s|\${REPO}|$(_sed_escape "$REPO_ROOT")|g" \
        "$_L_src" >"$_L_tmp"
    if _has_placeholders "$_L_tmp"; then
        rm -f -- "$_L_tmp"
        die "template '$1' stanza needs undeclared inputs (unrendered placeholders remain)"
    fi
    atomic_mv "$_L_tmp" "$4"
}

render_dev_stanza() { # <session> <id> <dest> — derive the dev stanza from the stable proxy file
    validate_session "$1"
    validate_id "$2"
    _L_src=$(proxy_file "$2")
    [ -f "$_L_src" ] || die "stable proxy file '$_L_src' is missing (it renders once at create time; restore it from git - proxy/deployments/ is committed)"
    _L_path=$(id_to_path "$2")
    _L_t=$(pin_template "$2")
    _L_kind=$(template_kind "$_L_t")
    # Every substitution is asserted: the stable pattern must be present and
    # the dev result must land, else the stable file was tampered with. The
    # temp file is allocated only after the pre-asserts pass, so failures
    # leave neither temp files nor empty dest dirs behind.
    _L_prefix="handle_path /$_L_path/*"
    _L_devprefix="handle_path /dev/$1/$_L_path/*"
    grep -q -F -- "$_L_prefix" "$_L_src" || die "stable proxy file '$_L_src' has no '$_L_prefix' line (tampered?)"
    if [ "$_L_kind" = "api" ]; then
        _L_sock="$2.sock"
        _L_devsock="$2.dev-$1.sock"
        grep -q -F -- "$_L_sock" "$_L_src" || die "stable proxy file '$_L_src' has no '$_L_sock' upstream (tampered?)"
        _L_tmp=$(tmp_in_dir "$(dirname -- "$3")")
        sed -e "s|$(_bre_escape "$_L_prefix")|$(_sed_escape "$_L_devprefix")|g" \
            -e "s|$(_bre_escape "$_L_sock")|$(_sed_escape "$_L_devsock")|g" \
            "$_L_src" >"$_L_tmp"
        grep -q -F -- "$_L_devsock" "$_L_tmp" || { rm -f -- "$_L_tmp"; die "dev derivation failed to rewrite the socket in '$_L_src'"; }
    else
        _L_root="$REPO_ROOT/bin/$_L_path"
        _L_devroot="$REPO_ROOT/run/$1/bundles/$_L_path"
        grep -q -F -- "$_L_root" "$_L_src" || die "stable proxy file '$_L_src' has no '$_L_root' root (tampered?)"
        _L_tmp=$(tmp_in_dir "$(dirname -- "$3")")
        sed -e "s|$(_bre_escape "$_L_prefix")|$(_sed_escape "$_L_devprefix")|g" \
            -e "s|$(_bre_escape "$_L_root")|$(_sed_escape "$_L_devroot")|g" \
            "$_L_src" >"$_L_tmp"
        grep -q -F -- "$_L_devroot" "$_L_tmp" || { rm -f -- "$_L_tmp"; die "dev derivation failed to rewrite the root in '$_L_src'"; }
    fi
    grep -q -F -- "$_L_devprefix" "$_L_tmp" || { rm -f -- "$_L_tmp"; die "dev derivation failed to rewrite the prefix in '$_L_src'"; }
    atomic_mv "$_L_tmp" "$3"
}

_wgc_die() { # <msg> — remove write_gen_config's temp files, then die
    rm -f -- "${_L_tmp:-/nonexistent}" "${_L_list:-/nonexistent}" "${_L_sorted:-/nonexistent}" 2>/dev/null || true
    die "$1"
}

write_gen_config() { # <dest> <ui-app-dir> <prefix>
    _L_dir=$2 _L_prefix=$3
    _L_tmp=$(tmp_in_dir "$(dirname -- "$1")")
    _L_list=$(mktemp) || _wgc_die "cannot create temp file"
    for _L_spec in "$_L_dir/spec/"*.openapi.json; do
        [ -e "$_L_spec" ] || break
        _L_api=$(basename -- "$_L_spec" .openapi.json)
        _id_shape_ok "$_L_api" || _wgc_die "snapshot '$_L_spec' names malformed API ID '$_L_api'"
        deployment_exists "$_L_api" || _wgc_die "dangling snapshot '$_L_spec' (no deployment '$_L_api')"
        _L_pt=$(pin_template "$_L_api")
        [ "$_L_pt" = "goa-api" ] || _wgc_die "snapshot '$_L_spec' refers to non-API deployment '$_L_api'"
        printf '%s %s\n' "$_L_api" "$_L_prefix/$(id_to_path "$_L_api")" >>"$_L_list"
    done
    if [ -s "$_L_list" ]; then
        _L_sorted=$(mktemp) || _wgc_die "cannot create temp file"
        sort "$_L_list" >"$_L_sorted" || _wgc_die "cannot sort snapshot list"
        {
            printf '{\n  "apis": {\n'
            _L_first=1
            while read -r _L_id _L_apipath; do
                if [ "$_L_first" -eq 1 ]; then _L_first=0; else printf ',\n'; fi
                printf '    "%s": "%s"' "$_L_id" "$_L_apipath"
            done <"$_L_sorted"
            printf '\n  }\n}\n'
        } >"$_L_tmp"
        rm -f -- "$_L_sorted"
    else
        printf '{\n  "apis": {}\n}\n' >"$_L_tmp"
    fi
    rm -f -- "$_L_list"
    atomic_mv "$_L_tmp" "$1"
}
