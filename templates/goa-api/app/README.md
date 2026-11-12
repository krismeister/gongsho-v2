# API deployment (goa-api template)

Scaffolded from the `goa-api` template (see `templates/goa-api/README.md` for
the scaffold contract). Goa design-first API: the contract lives in
`design/`, `gen/` is generated and committed, `service/` implements the
generated interfaces, one SQLite database per deployment, served on a unix
socket behind Caddy.

Deployment ID: `{{ID}}` (`{{PATH}}`).

## Prerequisites

- Go 1.27.3 or later. Dependency versions are pinned in `go.mod`/`go.sum`;
  no `goa` CLI install is needed (generation runs via `go run` from module
  dependencies).
- Caddy on `:8181` for proxied runs, `yq` for harness reads.
- The `tools/` harness verbs referenced below (`build`, `migrate`, `start`,
  `e2e`) are the primary path; direct commands follow each for fallback.

## Layout

- `design/` — the contract (app-owned, edit freely).
- `gen/` — generated from `design/` (committed, never hand-edited).
- `gen/openapi.json` — normalized OpenAPI 3.0 served at `GET /openapi.json`.
- `service/` — implementation behind the generated interfaces.
- `migrations/` — golang-migrate up/down pairs (app-owned, hand-authored).
- `e2e/` — HTTP flow tests (`go test ./e2e/`).
- `.example.env` — documents the runtime environment (reference only; the
  app never reads it). Copied to `.env` at scaffold.
- `main.go` — entrypoint: reads config from the environment, opens the DB,
  serves the unix socket.
- `.gongsho-deployment.yaml` — harness-owned pin (never hand-edit).

## Config

The app reads only the environment, never files. `start` sources `.env`
(settable tunables such as `LOG_LEVEL`), then exports the pin-derived
injected variables over it:

| Variable | Set by | Meaning |
|---|---|---|
| `SOCKET_PATH` | injected | unix socket to listen on |
| `DB_PATH` | injected | SQLite database file |
| `DEPLOYMENT_ID` | injected | underscore ID, served at `/info` |
| `TEMPLATE` | injected | template name, served at `/info` |
| `TEMPLATE_VERSION` | injected | template version, served at `/info` |
| `LOG_LEVEL` | tunable | `debug\|info\|warn\|error` (default `info`) |

The app never derives paths: it uses `SOCKET_PATH`/`DB_PATH` exactly as
given. It refuses to start when any injected variable is missing.

## Regenerate after design changes (from this dir)

```sh
go run goa.design/goa/v3/cmd/goa gen $(go list -m)/design
cp gen/http/openapi3.json gen/openapi.json
```

`gen/` must regenerate with no diff (regen-cleanliness gate):

```sh
git diff --exit-code -- gen/
```

## Build

```sh
tools/build {{ID}}          # from the repo root (primary)
go build -o /tmp/{{ID}}-api .  # direct (from this dir, tree stays clean)
```

## Migrate

```sh
tools/migrate {{ID}}        # from the repo root
```

Migrations run as an explicit step, never on boot. The server refuses to
start when the database file is missing or the schema check fails.

## Run

```sh
tools/start {{ID}}          # from the repo root (primary)
```

Direct (from the repo root; match what `start` would inject from the pin):

```sh
SOCKET_PATH=proxy/sockets/{{ID}}.sock DB_PATH=data/{{PATH}}/app.db \
  DEPLOYMENT_ID={{ID}} TEMPLATE=goa-api TEMPLATE_VERSION=1.0 \
  go run ./apps/{{PATH}}
```

The server unlinks a stale socket, listens on `SOCKET_PATH`, and shuts down
gracefully on SIGTERM.

Direct-socket checks (no Caddy, from the repo root):

```sh
curl --unix-socket proxy/sockets/{{ID}}.sock http://localhost/healthz
curl --unix-socket proxy/sockets/{{ID}}.sock http://localhost/info
curl --unix-socket proxy/sockets/{{ID}}.sock http://localhost/hello/world
curl --unix-socket proxy/sockets/{{ID}}.sock http://localhost/openapi.json
```

## E2E

```sh
tools/e2e {{ID}}            # from the repo root (primary)
E2E_APP_DIRECT=http://localhost:8181/{{PATH}} go test ./e2e/  # direct (stable route must be up)
```

The tests resolve their base URL from the single `E2E_APP_*` variable when
one is set, else from `E2E_BASE_URL`, and cover health, spec, identity
(`/info` id exact from the request URL, version present and wellformed),
then the example method.

## Extend

1. Edit `design/`, regenerate plus normalize (above), implement the new
   methods in `service/`.
2. Add a migration pair when the schema changes; never edit a landed
   migration, add a new one.
3. Rebuild, migrate a scratch copy first when unsure, run `go vet ./...`
   and the e2e tests.

## Contracts

- `GET /healthz` returns 200 plus exactly `{"status":"ok"}`.
- `GET /info` returns 200 plus `{"id","template","templateVersion"}` from
  the injected environment.
- `GET /openapi.json` serves `gen/openapi.json` (OpenAPI 3.0).
- The server listens on its unix socket only; Caddy strips the `/{{PATH}}/`
  prefix, so the app sees clean paths (`/hello/...`, `/healthz`, `/info`).
