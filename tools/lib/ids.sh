# lib/ids.sh — ID / path validation and derivation.
# Sourced via tools/lib.sh; never sourced or run alone.
#
# IDs are team_project_deployment (underscores); paths are team/project/deployment
# (slashes). Segments allow lowercase, digits, hyphens only; team `dev` is
# reserved (docs/phase-1/ids-and-routing.md).

_id_seg_ok() { # <segment> — 0 when the segment charset is legal
    case $1 in
        "" | *[!a-z0-9-]*) return 1 ;;
        *) return 0 ;;
    esac
}

_id_shape_ok() { # <id> — 0 when exactly three legal segments
    _L_s1=${1%%_*} _L_rest=${1#*_}
    [ "$_L_rest" != "$1" ] || return 1
    _L_s2=${_L_rest%%_*} _L_s3=${_L_rest#*_}
    [ "$_L_s3" != "$_L_rest" ] || return 1
    case $_L_s3 in *_*) return 1 ;; esac
    _id_seg_ok "$_L_s1" && _id_seg_ok "$_L_s2" && _id_seg_ok "$_L_s3"
}

_path_shape_ok() { # <path> — 0 when exactly three legal slash segments
    _L_s1=${1%%/*} _L_rest=${1#*/}
    [ "$_L_rest" != "$1" ] || return 1
    _L_s2=${_L_rest%%/*} _L_s3=${_L_rest#*/}
    [ "$_L_s3" != "$_L_rest" ] || return 1
    case $_L_s3 in */*) return 1 ;; esac
    _id_seg_ok "$_L_s1" && _id_seg_ok "$_L_s2" && _id_seg_ok "$_L_s3"
}

validate_id() { # <id> — dies with exit 2 unless a legal underscore ID
    case $1 in
        *"/"*) usage "want underscore ID (team_project_deployment), got path-like '$1'" ;;
    esac
    _id_shape_ok "$1" || usage "malformed deployment ID '$1' (want team_project_deployment, segments [a-z0-9-])"
    [ "${1%%_*}" != "dev" ] || usage "team 'dev' is reserved (it protects the /dev/ route prefix)"
}

validate_path() { # <path> — dies with exit 2 unless a legal slash path
    case $1 in
        *_*) case $1 in *"/"*) ;; *) usage "want slash path (team/project/deployment), got ID-like '$1'" ;; esac ;;
    esac
    _path_shape_ok "$1" || usage "malformed deployment path '$1' (want team/project/deployment, segments [a-z0-9-])"
    [ "${1%%/*}" != "dev" ] || usage "team 'dev' is reserved (it protects the /dev/ route prefix)"
}

validate_session() { # <session> — dies with exit 2 unless URL/filename-safe
    case $1 in
        "" | *[!a-z0-9-]*) usage "malformed session '$1' (want [a-z0-9-], e.g. a3f9)" ;;
    esac
    [ "${#1}" -le 32 ] || usage "malformed session '$1' (max 32 chars)"
}

validate_template_name() { # <name> — dies unless the template exists
    case $1 in
        "" | *[!a-z0-9-]*) usage "malformed template name '$1'" ;;
    esac
    [ -f "$REPO_ROOT/templates/$1/.gongsho-tpl.yaml" ] || usage "unknown template '$1' (want goa-api or react-ui)"
}

id_to_path() { printf '%s' "$1" | tr '_' '/'; }      # acme_shop_api-1 -> acme/shop/api-1
path_to_id() { printf '%s' "$1" | tr '/' '_'; }      # acme/shop/api-1 -> acme_shop_api-1
id_slug() { printf '%s' "$1" | tr 'a-z-' 'A-Z_'; }   # e2e env slug: ACME_SHOP_API_1
