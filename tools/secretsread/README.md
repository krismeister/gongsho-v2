# secretsread — read-only secret lookup for the verbs

Small Go helper verbs shell out to when they need a stored secret value.
It resolves org/team/project/deployment scope precedence against a SQLite
store and prints the value — nothing else — on stdout. The writer side
(the secrets API migrations) owns `secrets/schema.sql`; this tool only
reads it.

## Why Go, not the sqlite3 CLI

`sqlite3` is present on this machine but is not a documented harness
prerequisite, and adding one is a deliberate decision, not a default.
Go is already a prerequisite and `modernc.org/sqlite` (pure Go, pinned
to the same `v1.62.0` the templates use) is already in the module cache.
The binary is built per checkout by `tools/cache-warm` into
`tools/bin/secretsread`, mirroring the `migrate` precedent: a version
sidecar records the source hash, and verbs fall back to `go run` when
no matching prebuilt exists.

## Contract

- `secretsread --db PATH --org ORG --name NAME [--team TEAM] [--project PROJECT] [--deployment DEP]`
- Scope is org → team → project → deployment, most specific wins. Slugs
  repeat across parents, so every ancestor is always required: an empty
  team selects the org row, an empty project the team row, and a project
  without a team (or a deployment without a project) is malformed.
- Stdout carries only the value plus a trailing newline; diagnostics go
  to stderr (no value ever leaks into logs on failure paths).
- Exit 0 on a hit, 1 on any operational failure (missing file, unknown
  secret, unreadable store), 2 on usage errors. `--help` exits 0.
- Read-only by construction: `mode=ro` open (a missing file errors,
  never initializes) plus `PRAGMA query_only=ON`.
- Multiline values are refused: shell consumers capture stdout, and a
  wrapped value would corrupt sourcing. Writers must store single-line
  (base64) values.
- Values are opaque blobs: ciphertext in, ciphertext out. Decryption
  lands with the key-custody decision; this tool never sees keys.

## Verbs

Use `secrets_read <db> <org> <team> <project> <deployment> <name>` from
`tools/lib/env.sh` (prebuilt-or-`go run`, same shape as the `migrate`
lookup). Capture with `v=$(secrets_read ...)` and branch on the exit
code; on failure stdout is guaranteed empty.

## Tests

- `go test ./...` in this directory: precedence (including cross-org and
  cross-project isolation), validation, schema CHECKs, read-only posture,
  missing and empty stores. Fixtures are built from the real
  `secrets/schema.sql`, never a copy.
- `tools/tests/secretsread.sh`: the same contract through the compiled
  binary (build, help/usage codes, stdout purity, end-to-end precedence).
