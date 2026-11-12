# Template: goa-api (v1.0)

Design-first Goa API: DSL contract in, HTTP/JSON server plus OpenAPI out.
Each deployment owns one SQLite database and serves one unix socket behind
Caddy. This README is the scaffold contract: a fresh session follows it with
no other tribal knowledge. The `create` verb implements the render section
mechanically.

## Pinned versions

Exact pins live in `app/go.mod`/`app/go.sum` (shipped complete: `go mod tidy`
after scaffold changes nothing). Resolved at authoring (2026-11-11):

| Piece | Pin | Source |
|---|---|---|
| Go | 1.27.3 (`go` directive) | Goa v3.35.0 requires it; verified with `go1.27.3-X:nodwarf5`; go.dev stable was go1.27.4 |
| Goa CLI + lib | v3.35.0 | Go proxy `@latest`, GitHub latest release, quickstart install line (all agree) |
| modernc.org/sqlite | v1.62.0 | Go proxy `@latest` at authoring |
| testify | v1.12.1 | Go proxy `@latest` at authoring |

## Prerequisites

- Go 1.27.3 or later. No `goa` CLI install needed: generation runs via
  `go run` from module dependencies (`go install goa.design/goa/v3/cmd/goa@v3.35.0`
  is an optional convenience for `goa version` checks).
- No C compiler needed: the SQLite driver is pure Go, so plain `go build`
  works anywhere Go works.
- Caddy on `:8080` and `yq` for platform flows (proxying, harness reads).

## Layout

- `.gongsho-tpl.yaml` — manifest: `vars: [id]`, `owned: [proxy-stanza]`.
- `config/caddy/stanza` — owned proxy-stanza source with `{{ID}}`,
  `{{PATH}}`, `{{REPO}}` placeholders (renders to `proxy.md` shape verbatim).
- `config/health.json` — machine-readable health spec for harness probes:
  `{"path": ..., "status": ..., "body": ...}`.
- `app/` — scaffold source, copied to the deployment (only part Muse edits
  downstream): `design/`, `go.mod`/`go.sum`, `service/`, `migrations/`,
  `e2e/`, `.example.env`, `main.go`, `README.md`. `gen/` is NOT shipped: it
  is generated post-scaffold (its imports carry the rendered module path)
  and committed in the deployment.

## Scaffold (manual)

For ID `acme_shop_api-1` (`acme/shop/api-1`), from the repo root:

```sh
mkdir -p apps/acme/shop/api-1
cp -r templates/goa-api/app/. apps/acme/shop/api-1/
cd apps/acme/shop/api-1
grep -rl 'gongsho/template/goa-api' . | xargs sed -i 's|gongsho/template/goa-api|gongsho/acme/shop/api-1|g'
sed -i 's|{{ID}}|acme_shop_api-1|g; s|{{PATH}}|acme/shop/api-1|g' README.md
cp .example.env .env
go run goa.design/goa/v3/cmd/goa gen $(go list -m)/design
cp gen/http/openapi3.json gen/openapi.json
go mod tidy            # expect: no changes to go.mod/go.sum
go build ./... && go vet ./...
```

The harness then writes `.gongsho-deployment.yaml`, migrates the DB from
zero, renders `proxy/deployments/acme_shop_api-1` from `config/caddy/stanza`
(`{{REPO}}` is the checkout's absolute path), and reloads Caddy.

## Render contract (for `create`)

- Module token `gongsho/template/goa-api` → `gongsho/<team>/<project>/<deployment>`
  in `go.mod` plus every `.go` file (plain substring replace; the token
  appears nowhere else).
- `{{ID}}` → underscore ID, `{{PATH}}` → slash path, in `app/README.md`
  only. `.example.env` keeps its literal `{{...}}` marker lines forever:
  they document the injected variables and are never substituted.
- `{{ID}}`, `{{PATH}}`, `{{REPO}}` in `config/caddy/stanza` when rendering
  the proxy file. Moving a checkout requires re-rendering (absolute path).
- Scaffold order matters: render → `goa gen` → normalize copy → `go mod tidy`
  (tidy must see compiling code, so it runs after generation).

## Build contract

- `goa gen` emits `gen/`, including `gen/http/openapi3.json` (OpenAPI 3.0,
  the canonical document: widest consumer support; 2.0 is legacy, 3.2 too
  new). Normalization is `cp gen/http/openapi3.json gen/openapi.json`.
- `gen/` plus `gen/openapi.json` are committed; regen (`goa gen` + copy)
  must produce no diff: `git diff --exit-code -- gen/`.
- The binary embeds `gen/openapi.json`, so building without normalizing
  fails loudly at compile time.

## Runtime contract

- `start` ensures `.env` exists (copy from `.example.env` if missing),
  sources it for tunables, then exports the pin-derived injected variables
  over it and launches the binary with no flags: `bin/<path>/api`.
- The app reads only the environment. Required injected:
  `SOCKET_PATH`, `DB_PATH`, `DEPLOYMENT_ID`, `TEMPLATE`, `TEMPLATE_VERSION`.
  Optional tunable: `LOG_LEVEL` (`debug|info|warn|error`, default `info`).
  The app uses paths exactly as given and refuses to start when any
  injected variable is missing.
- The server unlinks a stale socket, listens on `SOCKET_PATH` only, and
  shuts down gracefully on SIGTERM inside the supervisor's grace window.
- `GET /healthz` returns 200 plus exactly `{"status":"ok"}`.
  `GET /info` returns `{"id","template","templateVersion"}` from the
  injected environment (truthful by construction).
  `GET /openapi.json` serves the embedded spec as `application/json`.

## Owned artifacts

Only `proxy-stanza` may be republished on upgrade. Everything under `app/`
is app property after scaffold.

## Guarantees

- Example service plus method in DSL shape (`Service`/`Method` with
  `Payload`, object `Result`, `HTTP GET` block).
- `gen/openapi.json` exists after build and is served at `/openapi.json`.
- `/healthz` per `config/health.json`; `/info` per the template spec.
- Unix-socket listen (verified at implementation with direct-socket curl).
- `migrations/0001_init.up/down.sql` constants-first pair.
- `e2e/e2e_test.go` passes via `E2E_APP_*` or `E2E_BASE_URL`, asserting
  `/info` (`id` exact from the request URL, version present and wellformed).

## Decisions (author's log)

- Config is environment-only: no config files read by the app, no path
  derivation, no flags. `.example.env` is reference documentation.
- SQLite engine is modernc.org/sqlite (pure Go): no C compiler beyond the
  repo's documented prerequisites, plain `go build` everywhere.
- Canonical spec is OpenAPI 3.0 (`gen/http/openapi3.json` → `gen/openapi.json`).
- Health is liveness-only (static OK); DB problems fail the start loudly
  instead of flapping health.
- `main.go` uses a blank `_ "embed"` import: this toolchain
  (`go1.27.3-X:nodwarf5`) reports a plain embed import as unused while the
  directive still embeds; the blank form compiles on standard Go too.
- The e2e tests prefer the single `E2E_APP_*` value and fall back to
  `E2E_BASE_URL`, satisfying both the template and e2e-standard wordings.
- The expected `/info` id derives from the request URL's last three path
  segments, so the same test works on stable and `/dev/<session>/` routes.
- Stanza uses tabs (caddy-fmt canonical); binary name suggestion is `api`
  under `bin/<path>/`; OpenAPI title stays Goa's default until Muse designs.
