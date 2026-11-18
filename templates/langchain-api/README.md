# Template: langchain-api (v1.0)

TypeScript LangGraph planning API: clarify loop, per-version approval
gate, frozen plan artifact. Each deployment owns one SQLite database
(graph checkpoints plus versioned drafts) and serves one unix socket
behind Caddy. This README is the scaffold contract: a fresh session
follows it with no other tribal knowledge. The `create` verb implements
the render section mechanically.

## Pinned versions

Exact pins live in `app/package.json` (shipped complete: `pnpm install`
after scaffold changes nothing). Resolved at authoring (2026-11-18):

| Piece | Pin | Source |
|---|---|---|
| Node | >=22.18.0 (`engines`) | `node:sqlite` plus type stripping need modern Node; verified on v26.13.0 |
| TypeScript | 5.9.3 | Same pin as `react-ui` |
| @langchain/langgraph | 1.7.5 | npm registry `latest` at authoring |
| @langchain/core | 1.4.1 | langgraph peer (`^1.3.4`), registry `latest` at authoring |
| @langchain/langgraph-checkpoint | 1.2.3 | langgraph dep (`^1.2.3`), direct for the saver base |
| zod | 4.6.7 | langgraph peer, registry `latest` at authoring |
| @types/node | 26.6.6 | Same pin as `react-ui` |

## Prerequisites

- Node.js >=22.18.0 and provisioned pnpm (`tools/cache-warm`).
- No LLM key needed: with no `LLM_API_KEY` the deterministic stub
  answers turns, so scaffold, build, check, and e2e run offline. Set
  `LLM_BASE_URL`/`LLM_API_KEY`/`LLM_MODEL` for real turns.
- Caddy on `:8181` and `yq` for platform flows (proxying, harness reads).

## Layout

- `.gongsho-tpl.yaml` — manifest: `vars: [id]`, `owned: [proxy-stanza]`.
- `config/caddy/stanza` — owned proxy-stanza source with `{{ID}}`,
  `{{PATH}}`, `{{REPO}}` placeholders (renders to `proxy.md` shape verbatim).
- `config/health.json` — machine-readable health spec for harness probes:
  `{"path": ..., "status": ..., "body": ...}`.
- `app/` — scaffold source, copied to the deployment (only part Muse edits
  downstream): `src/` (env, db, model, saver, graph, server, main),
  `migrations/` (sessions, drafts, checkpoint tables), `gen/openapi.json`
  (committed, served verbatim), `e2e/` (node:test flow), `.example.env`,
  `package.json`/`pnpm-lock.yaml`, `README.md`. `dist/` and
  `node_modules/` are never committed: build emits `dist/`, install
  provides `node_modules/`.

## Model protocol

One text protocol between graph and model: replies are `QUESTION: <text>`
or `PLAN: <json>`. The stub implements it deterministically; a real
model follows the system prompt in `src/model.ts`. Apps replace the
protocol with structured output as they grow — the approval gate and
draft store do not depend on it.

## Scaffold (manual)

For ID `acme_shop_plan-1` (`acme/shop/plan-1`), from `GONGSHO_HOME` (the
parent of the `gongsho_v2` checkout):

```sh
mkdir -p apps/acme/shop/plan-1
cp -r gongsho_v2/templates/langchain-api/app/. apps/acme/shop/plan-1/
cd apps/acme/shop/plan-1
sed -i 's|{{ID}}|acme_shop_plan-1|g; s|{{PATH}}|acme/shop/plan-1|g' README.md
cp .example.env .env
sh ../../../gongsho_v2/tools/pnpm install   # from the deployment dir
sh ../../../gongsho_v2/tools/pnpm exec tsc -b
```
