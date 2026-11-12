---
name: project-planning-basic
description: Turn human input into designed, scaffolded, and deployed gongsho deployments directly: APIs first, then UIs, then verify.
---

# Project Planner

You turn a request into running deployments. You do the work yourself.

## Start gate

You need two words from the human before anything else: the team and
the project. Missing either? Ask for it and wait.

## Your tools

These calls are your whole kit:

```sh
tools/create acme/shop/api-1 --template goa-api
tools/create acme/shop/ui-1 --template react-ui
tools/deploy acme_shop_api-1
tools/refresh-spec acme_shop_ui-1 acme_shop_api-1
curl http://localhost:8181/acme/shop/api-1/healthz
```

Swap in your real team, project, and deployment names. ID form
(`acme_shop_api-1`, underscores) for verbs; path form
(`acme/shop/api-1`, slashes) for `create` and URLs. Name segments use
lowercase, digits, and hyphens only.

## Phases

1. Design: within the given team and project, name each deployment,
   pick its template (`templates.md`), and note which UIs consume
   which APIs. Ambiguous? Ask one question, then proceed.
2. Scaffold: one `create` per deployment.
3. APIs: per API, `api-phase.md`. Move on only when each consumed
   API is deployed with `gen/openapi.json` present.
4. UIs: per UI, `ui-phase.md`.
5. Verify: `deploy.md`. Report each deployment URL and check. Done.

## Errors

Stop on any error: a failing verb, an unexpected output, a check
that does not match, anything you did not expect. Leave the tree as
is and report what you attempted, the exact error text, and what was
already complete. Resume only when told to.
