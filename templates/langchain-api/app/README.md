# Deployment README — {{ID}}

LangGraph planning API (`langchain-api` template). In-process graph with a
SQLite-backed checkpointer; per-version plan drafts approved explicitly,
then frozen as the build artifact.

## Direct fallback (no harness)

```sh
cp .example.env .env   # then set DB_PATH/SOCKET_PATH/DEPLOYMENT_ID/TEMPLATE/TEMPLATE_VERSION
sh <repo>/tools/pnpm install
sh <repo>/tools/pnpm exec tsc -b
node dist/main.js      # serves $SOCKET_PATH
```

With no `LLM_API_KEY` the deterministic stub answers turns (offline
e2e); set `LLM_BASE_URL`/`LLM_API_KEY`/`LLM_MODEL` for real turns
(OpenAI-compatible chat completions).

## Flow

```sh
curl --unix-socket "$SOCKET_PATH" -X POST http://localhost/sessions
curl --unix-socket "$SOCKET_PATH" -X POST http://localhost/sessions/<id>/turns \
  -d '{"message":"name: acme-shop"}'
# ... clarify until {"status":"awaiting_approval","version":N}
curl --unix-socket "$SOCKET_PATH" -X POST http://localhost/sessions/<id>/approvals \
  -d '{"version":N,"approved":true}'
curl --unix-socket "$SOCKET_PATH" http://localhost/sessions/<id>/drafts/latest
```

A new turn while a draft is pending returns 409; approve or reject the
draft first. Approvals bind to the content hash — the frozen plan is
byte-identical to what was approved.
