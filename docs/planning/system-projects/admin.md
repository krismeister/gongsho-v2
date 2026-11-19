# gongsho/admin — directory API plus admin console

Status: design locked 2026-11-18; not yet built. First doc under
`docs/planning/system-projects/` (system-lane project designs).

## Names

Reserved team `gongsho` (convention for now; `tools/lib/ids.sh`
enforcement lands when the tenant is built), project `admin`:

- API: path `gongsho/admin/api`, ID `gongsho_admin_api`
  - URL `http://localhost:8181/gongsho/admin/api/`
  - DB `data/gongsho_admin_api/app.db` (home root)
  - Socket `proxy/sockets/gongsho_admin_api.sock`, proxy file
    `proxy/deployments/gongsho_admin_api`
- Console: path `gongsho/admin/console`, ID `gongsho_admin_console`
  - URL `http://localhost:8181/gongsho/admin/console/`
  - Bundle root `bin/gongsho/admin/console`, proxy file
    `proxy/deployments/gongsho_admin_console`

No numeric suffixes: uniqueness comes from the full three-segment path,
and nothing under `tools/` or `templates/` depends on a numeric suffix.
All derivations verified against `tools/lib.sh` on 2026-11-18. ID rules
(`docs/ai/contracts/ids-and-routing.md`) unchanged. The `console` leaf
is the first incarnation of the roadmap's console effort
("gongsho-console"), not a competing surface.

## Console framework: React Admin

The console is a React Admin app. Its data provider is one generic
factory (~100–200 lines) over the Hey-generated API client,
parameterized per resource. List shapes are co-designed on the Goa side:
`{page, perPage, sort, filter}` in, `{data, total}` out. Batch and
reference methods ride on the single-item calls. No OpenAPI→provider
codegen until entity count justifies it. The console stays generic
(entities driven by API shape) so it could seed a future CMS template;
no template work now (see Deferred).

The Goa API follows json-server-provider conventions: plural collection
routes, `GET` list with `_sort`/`_order`/`_start`/`_end` plus an
`X-Total-Count` header, `GET` one, `POST` create, `PUT` update, `DELETE`
remove, id-array filtering for batch reads, JSON throughout.

## Entity model

Four tables. Every row carries `guid` (`TEXT PRIMARY KEY`, opaque,
minted at creation, immutable), human `name` (free label), `slug`
(immutable, unique among siblings — see Slug rules), parent FK by
parent `guid`, and `created` timestamp:

- `orgs(guid, slug UNIQUE, name, created)` — no parent, so the org
  slug is globally unique.
- `teams(guid, slug, name, org_guid REFERENCES orgs, created,`
  `UNIQUE(org_guid, slug))`
- `projects(guid, slug, name, team_guid REFERENCES teams, created,`
  `UNIQUE(team_guid, slug))`
- `deployments(guid, slug, name, project_guid REFERENCES projects,`
  `template, templateVersion, created, UNIQUE(project_guid, slug))` —
  mirrors pin fields (`template`, `templateVersion`, plus `db.path`
  for APIs).

Schema, FK enforcement, sibling scope, and GUID uniqueness proven in
ephemeral SQLite on 2026-11-18: same slug under two orgs accepted;
sibling dupe, orphan, and guid-dupe all rejected.

Terminology: "tenant" means today's "team" (top ID segment); "org" is
the roadmap's deferred org layer, kept management-only (a store row, not
a fourth path segment), so all routing/derivation stays valid.

## Slug rules

`slugify(name)`: lowercase, spaces/underscores to hyphens, strip anything
outside `[a-z0-9-]`. Proofs (2026-11-18): `"Acme Corp!"` → `acme-corp`,
`"a_b"` → `a-b`, `"admin"` → `admin` (all accepted); empty → rejected.

Slugs do three jobs here, not one: friendly URL segments; the
infrastructure identity substrate (the composed deployment ID, from which
every socket, proxy file, directory, and route derives); and the human
keys in the store. The rules below are identity rules wearing a slug
costume — that is why they carry this much weight.

- Scope: unique among siblings (within the parent), enforced by
  `UNIQUE(parent_guid, slug)`. Two orgs may each have team `shop`; two
  teams may each have project `store`; two projects may each have
  deployment `api`. Orgs have no parent, so org slugs are globally
  unique. Global-per-type uniqueness would wrongly forbid everyday
  repeats (every project wants an `api`), so it is explicitly rejected.
- Collision: exact-match reject against siblings; the human picks a new
  name. No auto-suffixing, so slugs stay predictable.
- Immutability: slugs are set at creation and never changed — no
  rename operation exists. To "rename", retire the entity and create a
  new one (new GUID). Display fixes go in `name`, which stays freely
  editable. Rationale: every filesystem path, socket, proxy file, and
  URL derives from the composed ID, so mutable slugs would mean moving
  all of that; immutability deletes the entire class of rename bugs.
- Composition: the deployment ID is pure composition
  (`team_slug_project_slug_deployment_slug`), derived by walking up
  from the deployment row — never assigned or stored independently in
  the store. The pin on disk carries the same string; equality is an
  invariant checked at creation (see Bootstrap rule).
- Until the deferred restricted-names policy lands, anything but empty
  goes — with one standing exception: team-level `dev` stays rejected
  (frozen routing rule protecting `/dev/`, not a new restriction).

## GUID rules

Assumed UUIDv4 text (flag to change). Primary key of every table:
parent links target GUIDs, which keeps keys narrow (no composite-key
cascades down the tree). Minted before the row exists; never reused.
No renames exist to survive — GUIDs serve as narrow PKs, parent links,
stable external references, and cross-machine-unique handles.

## Bootstrap rule

The admin project's own rows are seed data written at scaffold time.
Every later create runs, in order: mint GUID → sibling-slug check →
store row → composed-ID gate → filesystem/pin artifacts. The
composed-ID gate checks the full `team_project_deployment` ID for global
uniqueness (one lookup): since orgs sit outside the ID path, two orgs
could otherwise grow identical team/project/deployment slugs and collide
on disk. The second creator to try gets "deployment ID taken" even
though its own slugs are all sibling-legal. No rename flow exists —
immutable slugs mean a gated ID holds forever. During transition, pins
on disk stay authoritative; the store mirrors them until a cutover plan
exists (cutover deferred with migration).

## Non-goals

Migration, authentication, building/running either deployment, any
template work, CMS template commitment.

## Open questions

- Management-only org vs. fourth path segment (a fourth segment would
  materially change routing claims).
- GUID format (assumed UUIDv4).

## Deferred

- Restricted-names policy: full per-level policy, enforcement points,
  and restriction-adding discipline. Waits for API/console refinement.
- CMS standard template: intent recorded (console stays generic); the
  commitment (contract, name, versioning, self-hosting direction) waits
  for a real CMS to extract from.
- GUID-first identity: discuss replacing slug-composed infrastructure
  identity with opaque GUIDs (GUID sockets, dirs, routes), demoting slugs
  to pure URL cosmetics. A large derivation redesign for
  debatable gain — revisit only if readable identity stops pulling its
  weight.
