# Gongsho roadmap

Gongsho is becoming a pod-based application platform. The work runs as
three efforts in order: **templates**, then the **console**, then
**apps**. Templates are done; the console is next.

## Where things stand

**Templates — done.** Two runnable templates (`goa-api`, `react-ui`)
usable with Muse CLI, plus ID rules, Muse-ready READMEs, worked
examples, and one combined local demo wiring both. Per-API SQLite lives
inside `goa-api`, not as a separate template. Done meant: a fresh
session scaffolds from READMEs alone and passes the same health checks
as the direct path, and the combined demo runs and resets cleanly. The
full record lives in [templates.md](./templates.md).

**Console — next.** The overall API/DB plus UI over team, project, and
deployment records, and the main surface for modifying them. Starts
from green templates.

**Apps — after the console.** Applications built on top of the console.
Starts from a green console.

## How we build

These decisions hold until someone makes the case to change them:

- **Identity:** teams contain projects contain deployments. Deployments
  are long-lived workloads; pods are their runtime instances, so the
  leaf survives scale-out without a rename. Far future: an org layer
  above teams for ownership and billing across large clients — undecided
  whether it becomes a fourth path segment or stays management-only,
  and not designed for now.
- **Data:** SQLite, one database file per API, owned through the
  `goa-api` template; APIs stay single-instance. Backup is a file copy
  and permissions are one file per app — the properties a future
  deployment-versioning story (code plus DB snapshot) will build on,
  also not designed now. libSQL was evaluated and rejected as unneeded
  surface with a murkier roadmap; the shared file format keeps it a
  future swap.
- **Flows:** everything synchronous in the current scope (UI → API →
  DB). A queue returns when the first async need appears.
- **Process:** built with Muse CLI; template READMEs are the primary
  interface, and any local helper is optional convenience that must
  never be the only path. Supervision is a pidfile supervisor behind a
  per-deployment start/stop/restart/health interface; other
  environments replace the mechanism, not the interface.
- **UI:** `react-ui` is SPA-only (static, build-time content). Server
  rendering gets a separate `nextjs-ui` template later — no mode flags,
  no dual-personality templates.
- **Access control:** convention plus prompt scoping for now (agents
  write inside deployment dirs; the harness owns proxy files, build
  output, and pins). Hard sandboxing arrives with console mediation.
- **Portability:** templates stay compatible with a later pod target
  (smallest deployable unit, shared network/storage), with no pod
  packaging now. Local iteration follows Tilt behavior: watch files,
  rebuild, bring the environment up to date.

## What good looks like

- Each template scaffolds, runs, seeds, and reports health on its own,
  headless and via agent.
- Every API binds its own database; every UI renders from its API by ID.
- The combined demo comes up and resets with one action each.
- A fresh location plus a versioned artifact reproduces the demo with no
  tribal knowledge.

## Risks

- **Helper-path drift:** any helper must call the same scripts agents
  use; parity is tested, not assumed.
- **Scope creep:** console, packaging, and second-stack work stays out
  of the templates effort; the deferred list below holds the line.

## Not now

- **Console planning:** queue, console schema and migration story,
  packaging, chat role.
- **Apps planning:** app types, template binding, release flow.
- **Later, unphased:** two-backend OpenAPI handoff design; TanStack
  plugin toggle (when the first UI needs shared server-state caching);
  second reference stacks; multi-instance APIs; TLS, custom domains,
  host-based routing; zero-downtime deploy handoff; app-code upgrades.
- **Far future, with rationale under How we build:** the org layer and
  deployment versioning.

## Sources

- https://kubernetes.io/docs/concepts/workloads/pods/
- https://docs.tilt.dev/
- https://www.sqlite.org/about.html
- https://docs.turso.tech/libsql
