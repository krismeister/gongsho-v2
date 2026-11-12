# AGENTS.md — API deployment (goa-api)

Goa design-first JSON API on a unix socket behind Caddy. Contract in `design/`; `gen/` generated from it; `service/` implements it; one SQLite DB; flow tests in `e2e/`. Scope: this directory only — everything below is a path or command inside it.

## Build and test (from this dir)

- Regen after design edits: `go run goa.design/goa/v3/cmd/goa gen $(go list -m)/design`, then `cp gen/http/openapi3.json gen/openapi.json`. `gen/` must stay regen-clean (`git diff --exit-code -- gen/`).
- `go build ./...`, `go vet ./...`
- Flow tests: `go test ./e2e/` with `E2E_BASE_URL` (or one `E2E_APP_*`) pointing at the deployment.
- Running is the harness's job; see README for the direct fallback.

## Contracts

- Env-only config: `SOCKET_PATH`, `DB_PATH`, `DEPLOYMENT_ID`, `TEMPLATE`, `TEMPLATE_VERSION` injected by `start`; `LOG_LEVEL` tunable. The app reads env, never files, and uses paths verbatim.
- Migrations: explicit step, never on boot; never edit a landed migration, add a new pair.
- Routes: `GET /healthz` (exactly `{"status":"ok"}`), `GET /info` (`id`, `template`, `templateVersion`), `GET /openapi.json` (spec), plus the design's routes.
- Socket-only server; Caddy strips the deployment prefix, so the app sees clean paths.

## Never touch

- `.gongsho-deployment.yaml` (harness-owned pin), `gen/` (regenerate, don't edit).

## Detail

`README.md` (same dir) for commands and detail.
