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
- **Secrets:** third-party API keys that teams' APIs consume live in a
  central store scoped org → team → project → deployment, most
  specific wins (slugs repeat across parents). Ciphertext-only at rest from day
  one (AES-256-GCM, `v1:`-enveloped values); one machine-held master
  key derives per-scope keys in memory (HKDF-SHA256) — the method is
  public, only the master is secret. The console writes blind
  (metadata-only reads, no value-returning endpoint); rotation takes
  effect on restart; builds stay secret-free. The reader contract for
  verbs lives in `tools/secretsread/` (prebuilt-or-`go run` helper).
  Start-hook injection plus the operator keygen verb still land.
- **Project communication:** APIs call directly within a project;
  traffic to another project's API goes through the message queue
  only. The queue is the choke point (publish/subscribe still needs
  auth), and the rule commits cross-project traffic to async.
  Platform plumbing — secrets resolution at boot, harness, proxy, and
  the broker itself — stays synchronous: it cannot subscribe before
  it exists. Adopting this schedules the deferred queue decision
  (broker choice plus ordering and poison-message semantics).
- **Project separation:** the project is the unit of comprehension
  (one planner owns one project) and the future unit of sandbox
  containment; the deployment is the isolation unit (own process, DB
  file, env). Features that call each other directly live in one
  project — the secrets API sits in the admin project beside the
  console for exactly this reason (a cross-project console→secrets
  call would violate the queue rule above).

## What good looks like

- Each template scaffolds, runs, seeds, and reports health on its own,
  headless and via agent.
- Every API binds its own database; every UI renders from its API by ID.
- The combined demo comes up and resets with one action each.
- A fresh location plus a versioned artifact reproduces the demo with no
  tribal knowledge.
- Team API keys are stored encrypted by scope, managed in the console
  GUI, and reach deployments without touching builds.

## Risks

- **Helper-path drift:** any helper must call the same scripts agents
  use; parity is tested, not assumed.
- **Scope creep:** console, packaging, and second-stack work stays out
  of the templates effort; the deferred list below holds the line.
- **Key custody:** master-key loss means secret loss, and rotation
  tooling must land before the store holds real keys.

## Not now

- **Console planning:** queue selection (cross-project-via-queue adopted
  as the rule; broker choice plus semantics pending), console schema
  and migration story, packaging, chat role.
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
- https://www.rfc-editor.org/rfc/rfc5869
- https://docs.turso.tech/libsql
