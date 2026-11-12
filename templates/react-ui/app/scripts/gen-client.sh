#!/bin/sh
# Regenerate Hey API clients: one openapi-ts run per snapshot in spec/.
# An empty spec/ (fresh scaffold, no APIs wired yet) is a successful no-op.
# Client dirs whose snapshot is gone are pruned so stale output never lingers.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"

BIN="$ROOT/node_modules/.bin/openapi-ts"
if [ ! -x "$BIN" ]; then
  echo "gen-client: missing $BIN -- run 'npm install' first" >&2
  exit 1
fi

count=0
for spec in spec/*.openapi.json; do
  [ -e "$spec" ] || break
  id="$(basename -- "$spec" .openapi.json)"
  echo "gen-client: $id"
  # NOTE: -i/-o need ./-prefixed local paths; a bare relative path is
  # misread as a Hey API registry shorthand.
  "$BIN" -i "./spec/$id.openapi.json" -o "./src/client/$id"
  count=$((count + 1))
done

if [ -d src/client ]; then
  for dir in src/client/*/; do
    [ -d "$dir" ] || break
    id="$(basename -- "$dir")"
    if [ ! -e "spec/$id.openapi.json" ]; then
      echo "gen-client: prune stale client $id"
      rm -rf -- "$dir"
    fi
  done
fi

if [ "$count" -eq 0 ]; then
  echo "gen-client: no snapshots in spec/ -- nothing to generate (wire an API via refresh-spec)"
fi
