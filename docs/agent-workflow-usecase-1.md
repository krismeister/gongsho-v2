# agent-workflow-usecase-1 — Triage

Status: v1. Companion to `roadmap.md` (overall phases). This file owns the
human→agent routing workflow: how any human message becomes an answer, an edit,
or a question.

## Roles

- Human: talks naturally. Needs no knowledge of routing rules, workers, or instances.
- Planner: owns project state, coordination, and teardown. Wears the triage hat:
  classifying every human message is its first step, every turn.
- Workers (api-dev, ui-dev, …): execute tasks. Take tasking ONLY from planner.

Topology in v1: human ↔ planner ↔ workers. The human faces the planner alone;
no human→worker tasking, no worker→worker tasking.

## Operating context

Work happens inside one console portion at a time: project editing, team
editing, or whole-system editing. The active portion sets the lane — triage
never classifies it. During development the system portion is human-driven:
the human initiates and applies system edits (templates, harness, proxy main,
ID rules); agents assist only under direct human tasking, never autonomously.
Project and team portions are agent-operated through the planner.

## Triage decision

On every human message, the planner decides first:

1. Read / question / discussion → answer inline. Touch nothing, start nothing.
2. New edit → start a dev instance and run the edit flow below.
3. Ambiguous → ask ONE clarifying question, or explore read-only and propose
   the edit. Never mutate on ambiguity.
4. Continuing vs new: a message continuing an in-flight edit reuses its live
   session. If genuinely unclear, ask ("part of the current X edit, or
   something new?") rather than fork wrong.

## New-edit flow

1. Mint a session suffix (random, re-roll on collision). Unregistered and
   ephemeral by design; destroyed at cleanup.
2. Start dev instance(s): dev API copies on suffixed sockets with scratch DBs,
   UI scratch bundles as needed, `/dev/<session>/` E2E routes when UI
   verification is required. Stable is never touched by development work.
3. Planner frames task(s) to workers in plain language with intent and done
   criteria (e.g. "add property X to the schema, persisted; done = migrated
   scratch, healthy direct checks, report back").
4. Workers execute on dev copies only.
5. Completion reports flow back to planner: design diff, spec path plus served
   URL (APIs), migrations applied, health evidence, dev socket kept alive for
   downstream verification.
6. Cross-worker verification: the planner passes live dev addresses (e.g. ui-dev
   tests against api-dev's dev API, never stable) and owns teardown ordering —
   nothing is torn down while another worker still needs it.
7. Promotion: deploy API first (migrate the stable DB, restart, health-check
   through Caddy), then the UI bundle. Stable health checks, teardown of all
   dev copies, summary back to the human.

Parallel edits isolate by session; the planner tracks what is in flight.

## Standing rules

- Single source of truth per artifact: the DSL is the API contract (generated
  OpenAPI is derived truth); UI snapshots pin consumed specs.
- Regen-cleanliness: an API tree must regenerate with no diff; a UI build fails
  on spec drift until its snapshot is explicitly refreshed.
- The planner self-checks design changes. Humans view schema on request via the
  served OpenAPI, never as an approval gate.
- Enforcement in v1 is convention plus prompt scoping. Hard boundaries arrive
  with console mediation in Phase 2.
