# lib/log.sh — logging, exit paths, and prerequisite checks.
# Sourced via tools/lib.sh; never sourced or run alone.

log() { printf '[%s] %s\n' "$VERB" "$*"; }
err() { printf '[%s] %s\n' "$VERB" "$*" >&2; }
die() { err "error: $*"; exit 1; }
usage() { err "error: $*"; err "run 'tools/$VERB --help' for usage."; exit 2; }

need_cmd() { # <cmd> [what-for]
    command -v "$1" >/dev/null 2>&1 || die "missing required command '$1'${2:+ ($2)}"
}
