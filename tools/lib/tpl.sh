# lib/tpl.sh — per-template dispatcher (verbs branch on kind, drivers on template).
# Sourced via tools/lib.sh after the tpl-* driver modules; never sourced or run alone.
#
# Verbs keep branching only on the stable kind split (api|ui) from
# template_kind(). Anything that differs per template within a kind
# dispatches here, so a new template adds one driver file plus one
# case arm below instead of re-editing every verb.

_tpl_fn() { # <template> <suffix> — echoes tpl_<template>_<suffix> with hyphens as underscores
    _L_t=$1; _L_s=$2
    _L_t=$(printf '%s' "$_L_t" | tr '-' '_')
    printf 'tpl_%s_%s' "$_L_t" "$_L_s"
    unset _L_t _L_s
}

tpl_needs_install() { # <template> — 0 when the template installs node deps, 1 otherwise
    _T_t=$1
    case $_T_t in
        goa-api|langchain-api|react-ui) ;;
        *) die "unknown template '$_T_t' (want goa-api, langchain-api or react-ui)" ;;
    esac
    _T_fn=$(_tpl_fn "$_T_t" "needs_install")
    if "$_T_fn" "$_T_t"; then
        unset _T_t _T_fn
        return 0
    else
        unset _T_t _T_fn
        return 1
    fi
}

tpl_scaffold_api() { # <template> <id> <path> <app> — template-specific API scaffold step
    _T_t=$1; _T_id=$2; _T_path=$3; _T_app=$4
    case $_T_t in
        goa-api|langchain-api) ;;
        *) die "unknown API template '$_T_t' (want goa-api or langchain-api)" ;;
    esac
    _T_fn=$(_tpl_fn "$_T_t" "scaffold_api")
    "$_T_fn" "$_T_id" "$_T_path" "$_T_app"
    unset _T_t _T_id _T_path _T_app _T_fn
}

tpl_build_api() { # <template> <id> <app> <bin> <tools-dir> — template-specific API build
    _T_t=$1; _T_id=$2; _T_app=$3; _T_bin=$4; _T_d=$5
    case $_T_t in
        goa-api|langchain-api) ;;
        *) die "unknown API template '$_T_t' (want goa-api or langchain-api)" ;;
    esac
    _T_fn=$(_tpl_fn "$_T_t" "build_api")
    "$_T_fn" "$_T_id" "$_T_app" "$_T_bin" "$_T_d"
    unset _T_t _T_id _T_app _T_bin _T_d _T_fn
}

tpl_run_api_e2e() { # <template> <id> <tools-dir> — template-specific API e2e runner
    _T_t=$1; _T_id=$2; _T_d=$3
    case $_T_t in
        goa-api|langchain-api) ;;
        *) die "unknown API template '$_T_t' (want goa-api or langchain-api)" ;;
    esac
    _T_fn=$(_tpl_fn "$_T_t" "run_e2e")
    _T_rc=0
    "$_T_fn" "$_T_id" "$_T_d" || _T_rc=$?
    unset _T_t _T_id _T_d _T_fn
    return "$_T_rc"
}

tpl_regen_check() { # <template> <id> <app> <tools-dir> <h1> <h2> — template regen-cleanliness
    _T_t=$1; _T_id=$2; _T_app=$3; _T_d=$4; _T_h1=$5; _T_h2=$6
    case $_T_t in
        goa-api|langchain-api|react-ui) ;;
        *) die "unknown template '$_T_t' (want goa-api, langchain-api or react-ui)" ;;
    esac
    _T_fn=$(_tpl_fn "$_T_t" "regen_check")
    "$_T_fn" "$_T_id" "$_T_app" "$_T_d" "$_T_h1" "$_T_h2"
    unset _T_t _T_id _T_app _T_d _T_h1 _T_h2 _T_fn
}

tpl_cache_warm_template() { # <template> <pnpm-bin> — template-specific cache warming
    _T_t=$1; _T_pnpm_bin=$2
    case $_T_t in
        goa-api|langchain-api|react-ui) ;;
        *) die "unknown template '$_T_t' (want goa-api, langchain-api or react-ui)" ;;
    esac
    _T_fn=$(_tpl_fn "$_T_t" "cache_warm")
    "$_T_fn" "$_T_pnpm_bin"
    unset _T_t _T_pnpm_bin _T_fn
}
