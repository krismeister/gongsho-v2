# AGENTS.md — API deployment (langchain-api)

TypeScript LangGraph planning API on a unix socket behind Caddy. Contract in `gen/openapi.json` (committed, served verbatim); graph in `src/graph.ts`; per-version drafts in SQLite; flow tests in `e2e/`. Scope: this directory only — everything below is a path or command inside it.

## Build and test (from this dir)

- `sh <repo>/tools/pnpm exec tsc -b` (both app and e2e projects; `dist/` is build output, never committed).
- Running is the harness's job; see README for the direct fallback.
- Flow tests: `sh <repo>/tools/pnpm run test-e2e` with `E2E_BASE_URL` (or one `E2E_APP_*`) pointing at the deployment. Stub model, no key needed.

## Contracts

- Env-only config: `SOCKET_PATH`, `DB_PATH`, `DEPLOYMENT_ID`, `TEMPLATE`, `TEMPLATE_VERSION` injected by `start`; `LOG_LEVEL`, `LLM_*` tunables. The app reads env, never files, and uses paths verbatim.
- Migrations: explicit step, never on boot; never edit a landed migration, add a new pair.
- Routes: `GET /healthz` (exactly `{"status":"ok"}`), `GET /info` (`id`, `template`, `templateVersion`), `GET /openapi.json` (byte-identical to `gen/openapi.json`), plus the planning routes in the spec.
- Graph rule: side effects before `interrupt()`, never after — a resume re-runs the interrupted node, so `record` inserts the draft and `gate` only pauses and applies the verdict.
- Socket-only server; Caddy strips the deployment prefix, so the app sees clean paths.

## Never touch

- `.gongsho-deployment.yaml` (harness-owned pin), `gen/` (served verbatim; edits need a spec reason).
