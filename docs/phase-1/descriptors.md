# Descriptors

Two YAML files with distinct names. Quote versions and timestamps everywhere
(unquoted `1.0` parses as a float).

## `.gongsho-tpl.yaml` — template manifest

Template-owned; human-edited during development. Lives at
`templates/<name>/.gongsho-tpl.yaml`.

```yaml
name: goa-api
version: "1.0"
vars:
  - id
owned:
  - proxy-stanza
```

- `name` matches the template directory. `version` is two-part: major means
  existing apps must change to match, minor is everything else.
- `vars` declares scaffold inputs. v1 needs `id` only — everything derives
  from it. No undeclared inputs: a template needing anything else declares it
  first or the harness refuses to scaffold.
- `owned` lists artifacts the template may republish on upgrade. v1 holds the
  proxy stanza only; everything else is handed to the app forever.

## `.gongsho-deployment.yaml` — deployment pin

Harness-owned; never hand-edited. Lives at
`apps/<team>/<project>/<deployment>/.gongsho-deployment.yaml`. API example:

```yaml
id: acme_shop_api-1
path: acme/shop/api-1
template: goa-api
templateVersion: "1.0"
vars: {}
db:
  type: SQLite
  path: apps/acme/shop/api-1/app.db
created: "2026-11-11T12:00:00Z"
```

UIs use the identical shape minus `db` (absent means none).

- `id`/`path`: underscore and slash forms. Scaffold validates they agree.
- `template` plus exact `templateVersion`: the pin upgrades read later.
- `vars`: snapshot of non-derivable scaffold inputs; `{}` in v1, kept so the
  first real var needs no schema migration (assumed).
- `db` (APIs only): `type` plus repo-root-relative `path`, so every consumer
  resolves it identically regardless of working directory.
- `created`: quoted RFC3339 timestamp.

Validation runs in `lib.sh` at create time: YAML parses, required fields
present, id is three `[a-z0-9-]+` segments joined by `_`, path segments equal
id segments, team is not `dev`, template exists.
