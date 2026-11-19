# lib/tpl-react-ui.sh — react-ui template driver (Node static UI).
# Sourced via tools/lib.sh; never sourced or run alone. See tpl-goa-api.sh
# for the interface contract and the _T_ locals convention.

tpl_react_ui_needs_install() { # <template> — 0: UIs install via pnpm
    return 0
}

tpl_react_ui_scaffold_api() { # never called (react-ui is not an API kind)
    die "internal: react-ui has no API scaffold"
}

tpl_react_ui_build_api() { # never called (react-ui is not an API kind)
    die "internal: react-ui has no API build"
}

tpl_react_ui_run_e2e() { # never called through the API runner (UIs run via the browser flow)
    die "internal: react-ui has no API e2e runner"
}

tpl_react_ui_regen_check() { # <id> <app> <tools-dir> <h1> <h2> — src/client/ regen-clean
    _T_id=$1; _T_app=$2; _T_d=$3; _T_h1=$4; _T_h2=$5
    ( cd "$_T_app" && find src/client -type f -exec sha256sum {} + | sort -k2 ) >"$_T_h1" || die "cannot hash src/client/"
    ( cd "$_T_app" && sh "$_T_d/pnpm" run gen-client ) || die "client regen failed (see above)"
    ( cd "$_T_app" && find src/client -type f -exec sha256sum {} + | sort -k2 ) >"$_T_h2" || die "cannot hash src/client/"
    cmp -s -- "$_T_h1" "$_T_h2" || die "src/client/ is not regen-clean (regeneration changed committed output)"
    log "src/client/ regen-clean"
    unset _T_id _T_app _T_d _T_h1 _T_h2
}

tpl_react_ui_cache_warm() { # <pnpm-bin> — prefetch the template deps to the shared store
    _T_pnpm_bin=$1
    _T_ft=$(mktemp -d) || die "cannot create temp dir"
    cp -- "$REPO_ROOT/templates/react-ui/app/package.json" "$REPO_ROOT/templates/react-ui/app/pnpm-lock.yaml" "$_T_ft/" || { rm -rf -- "$_T_ft"; die "cannot stage UI manifests"; }
    ( cd "$_T_ft" && "$_T_pnpm_bin" fetch --store-dir "$REPO_ROOT/.cache/pnpm/store" ) || { rm -rf -- "$_T_ft"; die "pnpm fetch failed (see above)"; }
    rm -rf -- "$_T_ft"
    log "UI dependencies prefetched to the shared store"
    unset _T_pnpm_bin _T_ft
}
