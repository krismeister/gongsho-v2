# Tools

One `.sh` verb per file plus shared `lib.sh` (assumed). Conventions for every
verb: strict mode, `--help`, explicit args, exit 0 success / 1 operational
failure with a message / 2 usage error, temp-then-rename for all writes,
`[verb]` log prefix. YAML reads go through `yq` (documented prerequisite
alongside Go, Node, Caddy).

## Project-lane verbs (human now, agents later)

- `create <path> --template <name>` — validate ID, scaffold app, write pin,
  create empty DB plus migrate to latest, render proxy file, reload Caddy.
  Verb name `create` assumed.
- `build <id>` — app source to mirrored `bin/` output (atomic promotion via
  `.new` plus rename). API output is a single binary at `bin/<id>/api`
  (assumed name); UI output is the static bundle only — `bin/` never holds
  anything else. UI builds regen Hey API clients from snapshots first, but
  only after the freshness check passes, so regen input is pinned and the
  write is normally a no-op; unexpected diffs surface in git status. Never
  touches proxy, DBs, or processes.
- `deploy <id>` — build, ensure proxy file, reload, migrate plus restart
  (APIs) or bundle swap (UIs), verify through Caddy. Restores DB backup and
  aborts loudly on failure.
- `retire <id>` — stop, remove proxy file plus reload, archive the app dir
  plus its `data/` dir (in v1, assumed; archive alongside, never auto-delete).
- `start|stop|restart|status <id>` — pidfile supervision; status covers
  process state plus endpoint health.
- `dev-up <session> <id>...` — dev copies for a session: sockets, scratch
  DBs, `/dev/` routes (routes only; e2e builds its bundle first — assumed).
- `dev-down <session>` — kill copies, remove routes plus reload, delete
  scratch. Manual cleanup for orphans; no sweep verb in v1.
- `check <id>` — direct-socket API checks plus UI bundle checks. No browser.
- `e2e <id>...` — hermetic browser run per the e2e standard.
- `refresh-spec <ui-id> <api-id>` — explicit snapshot copy. Never automatic.
- `migrate <id>` — backup (stable only), migrate up, verify version. Read by
  deploy and dev flows; runnable standalone for inspection.

## System-lane verbs (human-driven)

- `template-check <template>` — scaffold a scratch app, build, check, tear
  down. Required by the exit gate.
- `template-new` skipped for v1 (assumed); version bumps ride the later
  upgrade mechanism.

## `lib.sh` (sourced, never run)

Thin wrapper: globals, frozen constants, and `VERB` default, then sources
every module in `lib/`. Verbs source `tools/lib.sh` only, never modules
directly. One concern per module file:

- `log.sh` — `log`/`err`/`die`/`usage`, exit 1/2 discipline.
- `ids.sh` — ID/path/session validation and ID↔path derivation.
- `paths.sh` — tree/socket/pidfile/proxy path builders.
- `pin.sh` — YAML reads via mikefarah `yq` (flavor-guarded), pin
  validation, template kind.
- `io.sh` — dir ensure, atomic temp-then-rename writes, time, session
  minting, hashing, Go-cache fallback plus `GOFLAGS` handling (see
  `environments.md`).
- `caddy.sh` — Caddy reload.
- `health.sh` — direct-socket and TCP getters, JSON comparison,
  polled health wait.
- `proc.sh` — pidfile reads, liveness, supervised stop.
- `render.sh` — stable stanza render, asserted dev-stanza derivation,
  `gen-config.json` writer.
- `env.sh` — `.env` ensure plus source, pin-derived injected exports.

## `tests/` (committed, hermetic)

`tools/tests/run.sh` runs every suite with a combined pass/fail
summary and exits nonzero on any failure. Suites derive the repo root
from their own location, build all fixtures at runtime under `mktemp`
scratch (trap-cleaned), and work against fake repos only — the real
`apps/`, `bin/`, `proxy/`, `run/`, and `tools/` trees are never
written. Static fixtures live under `tools/tests/fixtures/`. Every
verb carries positive plus key failure cases here; `lib.sh` changes
must keep the suite green unmodified unless the change itself is the
contract.
