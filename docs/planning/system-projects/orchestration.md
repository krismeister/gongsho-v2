# Creation flow — GUI to codegen to verbs

Status: plan locked 2026-11-18; not yet built. Companion to `admin.md`
(the locked store design: names, keys, gates). Lives under
`docs/planning/system-projects/`.

## Source of truth

The API. Rows are written by the console API as part of its own
orchestration — registration is not after-the-fact sync. Anything on
disk without a row is an orphan by definition; ongoing orphan handling
is deferred (see Deferred), and backfill below covers only the current
disk state, once.

## Architecture

GUI → codegen layer → verbs as tools. The codegen layer is the console
API's orchestration endpoints: they validate, write rows, invoke
`tools/*` verbs, and report. The GUI calls these endpoints; it never
touches verbs or the DB directly. Verbs stay dumb filesystem/proxy
tools: no registration code, flags, or API-calling behavior is added to
them, and they remain usable standalone as escape hatches.

## Orchestrated create

Order: validate lineage → mint GUID → sibling-slug check → store row →
composed-ID gate → invoke `tools/create` for scaffold/pin/migrate/proxy
→ report. Gates are the `admin.md` rules (sibling uniqueness, global
composed-ID check).

- Rollback (proposed; see Open questions): if the verb fails after the
  row write, the API deletes the row — it never represented a live
  deployment. This is the one place deletion beats marking.
- Verb invocation semantics (cwd, env, timeout, log capture,
  concurrency) are pinned in the endpoint contract before
  implementation.

## Orchestrated retire

Order: mark the row `retired` (nullable timestamp, never delete — the
audit trail retire preserves) → invoke `tools/retire` for
stop/unroute/archive → report.

## Skills path (proposed; see Open questions)

Terminal agents create through the same API endpoints as the GUI — one
creation path for humans and agents, single writer. The planner skill's
kit list switches from `tools/create` to the API path once the
endpoints land.

## Lineage

Org arrives as a request field on the orchestration endpoint (the GUI
supplies it), defaulting to a seeded `local` org. The reserved `gongsho`
team lives under a seeded `gongsho` org via seed data, not the default.
Registration upserts missing parent rows, then inserts the deployment
row under all gates.

## Bootstrap era

Until the orchestration endpoints exist, skills keep calling verbs
directly and registration simply doesn't happen yet. Once the endpoints
land: backfill once (below), switch skills to the API path, steady
state from there. The in-flight console build stays unblocked
throughout — no flag days in the verbs.

## Backfill (one time)

Map every pin on disk to an org, then register each once through the
same gates as a live create. Current disk state: `myco-test2` pair,
`gongsho/admin` pair (seed-covered), `tplcheck` scratch (fate TBD —
recommend retire outright). Backfill is a single run, not a standing
process; anything created outside the API afterwards is an orphan and
waits for the deferred handling.

## Validation (at implementation)

- Endpoint contract accepted on paper before the builder implements it
  (covers verb-invocation semantics too).
- Orchestrated create: one call yields both the API-readable row and
  the on-disk app dir, pin, and proxy file.
- Forced verb failure mid-flow: row gone, API reports the verb's error
  text (no bare 500).
- Escape hatch intact: direct `tools/create` still works standalone
  with the API down.
- Backfill: row counts match walked pins plus seeds, one list call per
  table.

## Open questions

- Skills-via-API vs. skills-keep-verbs (recommended: via API).
- Delete-on-failed-orchestration vs. mark-failed (recommended: delete).
- Org for `myco-test2`, fate of `tplcheck` (recommended: `local`,
  retire scratch).
- `local`/`gongsho` seeds (recommended as written).

## Deferred

- Orphan projects: ongoing detection and repair of anything created
  outside the API (escape-hatch verb use, crash windows, hand edits).
  Explicitly not handled until the API is the established creation
  path; backfill covers history, this covers the future.

## Non-goals

Auth, console UI work beyond calling the endpoints,
pins-authoritative cutover (still deferred per `admin.md`), any verb
behavior changes.
