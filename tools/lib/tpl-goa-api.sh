# lib/tpl-goa-api.sh — goa-api template driver (Go toolchain).
# Sourced via tools/lib.sh; never sourced or run alone.
#
# Every driver implements the same small interface; the dispatcher in
# lib/tpl.sh routes by template name. Function names use the
# tpl_<template>_verb shape (hyphens become underscores). Locals use
# the _T_ prefix so driver frames never clobber verb variables.

tpl_goa_api_needs_install() { # <template> — 1: goa APIs have nothing to install
    return 1
}

tpl_goa_api_scaffold_api() { # <id> <path> <app> — module render plus gen plus tidy
    _T_id=$1; _T_path=$2; _T_app=$3
    _T_mod="gongsho/$_T_path"
    ( cd "$_T_app" && grep -rl 'gongsho/template/goa-api' --include='*.go' --include='go.mod' . | while IFS= read -r _T_f; do
        sed -i "s|gongsho/template/goa-api|$_T_mod|g" "$_T_f"
    done ) || die "module path render failed"
    if grep -rq 'gongsho/template/goa-api' "$_T_app" --include='*.go' --include='go.mod'; then
        die "module token render incomplete"
    fi
    grep -q -F -- "$_T_mod" "$_T_app/go.mod" || die "module render produced no result in go.mod"
    need_cmd go "Go toolchain (documented prerequisite)"
    _T_modline=$(cd "$_T_app" && go list -m 2>&1) || die "go list failed: $_T_modline"
    ( cd "$_T_app" && go run goa.design/goa/v3/cmd/goa gen "$_T_modline/design" ) || die "goa gen failed (see above)"
    [ -f "$_T_app/gen/http/openapi3.json" ] || die "goa gen emitted no gen/http/openapi3.json"
    _T_gtmp=$(tmp_in_dir "$_T_app/gen")
    cp -- "$_T_app/gen/http/openapi3.json" "$_T_gtmp" || die "spec normalize copy failed"
    atomic_mv "$_T_gtmp" "$_T_app/gen/openapi.json"
    ( cd "$_T_app" && go mod tidy ) || die "go mod tidy failed (see above)"
    # NOTE: tidy self-heals the scaffold's pins; per the staleness rule
    # (manifest versions only) there is no file-content drift verdict on
    # this path — template validity belongs to template-check.
    log "scaffolded API (module $_T_mod, gen/ generated)"
    unset _T_id _T_path _T_app _T_mod _T_modline _T_gtmp _T_f
}

tpl_goa_api_build_api() { # <id> <app> <bin> — regen gen/ plus go build with promotion
    _T_id=$1; _T_app=$2; _T_bin=$3
    need_cmd go "Go toolchain (documented prerequisite)"
    _T_modline=$(cd "$_T_app" && go list -m 2>&1) || die "go list failed: $_T_modline"
    ( cd "$_T_app" && go run goa.design/goa/v3/cmd/goa gen "$_T_modline/design" ) || die "goa gen failed (see above)"
    [ -f "$_T_app/gen/http/openapi3.json" ] || die "goa gen emitted no gen/http/openapi3.json"
    _T_gtmp=$(tmp_in_dir "$_T_app/gen")
    cp -- "$_T_app/gen/http/openapi3.json" "$_T_gtmp" || die "spec normalize copy failed"
    atomic_mv "$_T_gtmp" "$_T_app/gen/openapi.json"
    rm -rf -- "${_T_bin}.new"
    mkdir -p -- "${_T_bin}.new" || die "cannot create build scratch"
    ( cd "$_T_app" && go build -o "${_T_bin}.new/api" . ) || die "go build failed (see above)"
    rm -rf -- "$_T_bin" || die "cannot replace old output"
    mv -- "${_T_bin}.new" "$_T_bin" || die "bin promotion failed"
    log "built $_T_bin/api"
    unset _T_id _T_app _T_bin _T_modline _T_gtmp
}

tpl_goa_api_run_e2e() { # <id> <tools-dir> — go test over the app dir
    _T_id=$1
    _T_rc=0
    ( cd "$(app_dir "$_T_id")" && go test ./e2e/ ) || _T_rc=$?
    unset _T_id
    return "$_T_rc"
}

tpl_goa_api_regen_check() { # <id> <app> <tools-dir> <h1> <h2> — gen/ regen-clean
    _T_id=$1; _T_app=$2; _T_h1=$4; _T_h2=$5
    ( cd "$_T_app" && find gen -type f -exec sha256sum {} + | sort -k2 ) >"$_T_h1" || die "cannot hash gen/"
    _T_modline=$(cd "$_T_app" && go list -m 2>&1) || die "go list failed: $_T_modline"
    ( cd "$_T_app" && go run goa.design/goa/v3/cmd/goa gen "$_T_modline/design" && cp gen/http/openapi3.json gen/openapi.json ) || die "regen failed (see above)"
    ( cd "$_T_app" && find gen -type f -exec sha256sum {} + | sort -k2 ) >"$_T_h2" || die "cannot hash gen/"
    cmp -s -- "$_T_h1" "$_T_h2" || die "gen/ is not regen-clean (regeneration changed committed output)"
    log "gen/ regen-clean"
    unset _T_id _T_app _T_h1 _T_h2 _T_modline
}

tpl_goa_api_cache_warm() { # warming needs no pnpm bin; warms the Go module plus goa CLI caches
    log "downloading goa-api template modules"
    # NOTE: download from a temp copy — `go mod download all` records sums
    # into go.sum, and the template's copy must stay tidy-canonical.
    _T_dl=$(mktemp -d) || die "cannot create temp dir"
    cp -- "$REPO_ROOT/templates/goa-api/app/go.mod" "$REPO_ROOT/templates/goa-api/app/go.sum" "$_T_dl/" || { rm -rf -- "$_T_dl"; die "cannot stage module files"; }
    ( cd "$_T_dl" && go mod download all ) || { rm -rf -- "$_T_dl"; die "go mod download failed (see above)"; }
    rm -rf -- "$_T_dl"
    _T_goaver=$(cd "$REPO_ROOT/templates/goa-api/app" && go list -m goa.design/goa/v3 2>&1) || die "go list failed: $_T_goaver"
    _T_goaver=${_T_goaver##* }
    case $_T_goaver in v*) ;; *) die "unexpected goa version '$_T_goaver'" ;; esac
    _T_gobin=$(mktemp -d) || die "cannot create temp dir"
    GOBIN="$_T_gobin" go install "goa.design/goa/v3/cmd/goa@$_T_goaver" || { rm -rf -- "$_T_gobin"; die "goa install failed (see above)"; }
    rm -rf -- "$_T_gobin"
    log "goa $_T_goaver compiled (build cache warm)"
    unset _T_dl _T_goaver _T_gobin
}
