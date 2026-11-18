# Template: langchain-api

Stack: TypeScript on Node.js with LangGraph (`@langchain/langgraph`),
HTTP/JSON only. In-process graph, SQLite-backed checkpointer, stub model
when no key is set. Node 22.18.0 or later; exact versions in
`templates/langchain-api/app/package.json`.

## Scaffold (`templates/langchain-api/app/`, copied to the deployment)

- `src/main.ts` — entrypoint: reads `DB_PATH`/`SOCKET_PATH` from the
  environment (injected by `start`; the app never derives paths), opens
  the DB, serves the API on the unix socket.
- `src/server.ts` — routes: platform contract (`GET /healthz`,
  `GET /info`, `GET /openapi.json`) plus planning routes (`POST
  /sessions`, `POST /sessions/:id/turns`, `POST
  /sessions/:id/approvals`, `GET /sessions/:id/drafts/latest`).
- `src/graph.ts` — StateGraph: `converse` (clarify or draft), `record`
  (insert draft version), `gate` (`interrupt()` for per-version
  approval). Side effects live in `record` only: resume re-runs the
  interrupted node, so nothing after `interrupt()` may write.
- `src/saver.ts` — `SqliteSaver`, a `BaseCheckpointSaver` over
  `node:sqlite` mirroring `MemorySaver` semantics (tables owned by
  migrations, applied by the harness, never here).
- `src/model.ts` — one model function over the `QUESTION:`/`PLAN:`
  protocol; OpenAI-compatible endpoint when `LLM_API_KEY` is set,
  deterministic stub otherwise.
- `src/db.ts`, `src/env.ts` — row helpers plus env-only config.
- `migrations/0001_init.up/down.sql` — sessions, plan versions, and
  checkpoint tables (golang-migrate file convention).
- `gen/openapi.json` — committed spec, served verbatim at
  `GET /openapi.json`.
- `e2e/plan.test.ts` — node:test flow via `E2E_BASE_URL` (or one
  `E2E_APP_*`), same resolution rule as the goa e2e.
- `.example.env` — documents app env: injected `{{DB_PATH}}`/`{{SOCKET_PATH}}`
  (never set here) plus settable tunables (`LOG_LEVEL`, `LLM_*`). Copied
  to `.env` at scaffold; the app never reads this file directly.
- `README.md`, `AGENTS.md` — scaffold, run, wire, and test commands for Muse.

## Build and guarantees

- `tsc -b` (app plus e2e projects) emits `dist/`; build writes a
  generated `bin/api` node launcher (atomic promotion) that runs the
  deployment's own `dist/` plus `node_modules` in place — 90M of deps
  are never copied per build, and dev copies run the same stable build
  goa APIs do.
- Health: `GET /healthz` returns 200 plus `{"status":"ok"}` (assumed shape).
- Info: `GET /info` returns `id`, `template`, `templateVersion` (all injected
  env, so always truthful). Permanent endpoint, asserted by e2e.
- Spec: `GET /openapi.json` is byte-identical to `gen/openapi.json`
  (check asserts this; template-check asserts the contract paths exist).
- The server listens on its unix socket (acceptance criterion).
- Turns: a new turn while a draft is pending returns 409; approvals bind
  to the draft version and return its content hash, so the frozen plan is
  byte-identical to what was approved.
