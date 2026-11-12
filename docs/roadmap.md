# Gongsho — roadmap

Last updated: 2026-11-11. Phase 1 detailed plan lives in phase-1/phase-plan.md; Phases 2–3 intentionally thin.

## Goal

Build gongsho, a pod-based application platform, in three phases: templates first, then gongsho-console, then gongsho-apps. Phase 1 produces two runnable templates (`goa-api`, `react-ui`) usable with Muse CLI. Per-API SQLite lives inside `goa-api`, not as a separate template. Gongsho-console becomes the overall API/DB plus UI over team/project/deployment records and the main modification surface. Gongsho-apps are built on the console.

## Key decisions (locked unless noted)

- IDs are team → project → deployments. Deployments are long-lived workloads; pods are their runtime instances, so the leaf survives scale-out without a rename.
- Far future: an org layer above teams for large clients (ownership/billing grouping across many teams). Undecided whether it becomes a fourth path segment or stays management-only; do not design for it now.
- Future: deployment versioning including DB copies (a version pins code plus a database snapshot). This builds on the SQLite properties behind the choice: backup is a file copy, permissions are one file per app. Do not design it now.
- Phase 1 DB is SQLite: serverless, zero-config, whole database in a single disk file ([About SQLite](https://www.sqlite.org/about.html)). Each API owns its DB via the `goa-api` template; APIs stay single-instance in v1.
- libSQL evaluated as the alternate: production-ready SQLite fork, same file format and API, extras like vector search ([libSQL docs](https://docs.turso.tech/libsql)). Rejected for Phase 1 as unneeded surface with a murkier roadmap (same docs steer new projects to Turso Database). Shared format keeps it a future swap behind the DB contract.
- No queue in v1: all flows are synchronous (UI → API → DB). Queue returns in later planning when the first async need appears.
- Phase 1 is built with Muse CLI per your choice; template READMEs are the primary interface. The local helper (working name poddev) is optional convenience only and must never be the sole path.
- Process supervision in v1 is a pidfile-supervisor: deploy stops/starts each API by pidfile, then health-checks through Caddy. Non-local environments will replace it behind the same per-deployment start/stop/restart/health interface.
- `react-ui` is SPA-only in v1 (static, build-time content). Server-rendered SEO pages get a separate `nextjs-ui` template later; no mode flag, no dual-personality template.
- Access control in v1 is convention plus prompt scoping: Muse writes only inside deployment dirs while the harness owns proxy files, build output, and pins. Hard sandboxing arrives with console mediation in Phase 2.
- Templates stay compatible with a later pod target: smallest deployable unit, containers with shared network/storage and a run spec ([Pods](https://kubernetes.io/docs/concepts/workloads/pods/)). No pod packaging in Phase 1.
- Optional local iteration follows Tilt behavior: watch files, build images, bring the environment up to date ([Tilt](https://docs.tilt.dev/)).

## Phase 1 — templates

Deliverables: `goa-api` and `react-ui` templates plus ID rules, Muse-ready READMEs, worked examples, and one combined local demo wiring both. Detailed plan: phase-1/phase-plan.md. Exit criterion: fresh-prompt Muse scaffold from READMEs alone passes the same health checks as the direct path, and the combined demo runs and resets cleanly.

## Phase 2 — gongsho-console (thin, deferred)

Goal: overall API/DB plus UI for team/project/deployment records as the main modification surface. Entry: Phase 1 exit green. Deferred items: see Deferred decisions.

## Phase 3 — gongsho-apps (thinnest, deferred)

Goal: build apps on the console. Entry: Phase 2 console green. Deferred items: see Deferred decisions.

## Validation gates

- Each template scaffolds, runs, seeds, and reports health independently, headless and via Muse.
- API binds its own DB; UI renders from its API by ID.
- Combined demo brings up both with one action and resets to clean state.
- Fresh location plus versioned artifact reproduces the demo without tribal knowledge.

## Risks

- Helper-path drift from the direct path; the helper must call the same scripts Muse uses.
- Phase 2/3 creep into Phase 1; deferred lists above hold the line.

## Deferred decisions

- To Phase 2 planning: queue, console schema, console migration story,
  packaging, chat role.
- To Phase 3 planning: app types, template binding, release flow.
- Later, unphased: two-backend OpenAPI handoff design (snapshots already
  anticipate multi-API); TanStack plugin toggle (when the first UI needs
  shared server-state caching); second reference stacks; multi-instance APIs;
  TLS, custom domains, host-based routing; zero-downtime deploy handoff;
  app-code upgrades (proxy-regen first; template-v2 publish bundle of migrated
  example, per-version upgrade guides, and worker execution flow designed then).
- Far-future items with rationale (org layer, deployment versioning) stay
  under Key decisions above.

## Sources

- https://kubernetes.io/docs/concepts/workloads/pods/
- https://docs.tilt.dev/
- https://www.sqlite.org/about.html
- https://docs.turso.tech/libsql
