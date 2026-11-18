---
title: Runbook
description: Machine facts every agent needs.
---

## Roots

| Tree | Root | Notes |
|---|---|---|
| `apps/<team>/<project>/<deployment>/` | `GONGSHO_HOME` | Deep; planners write here only |
| `data/<team_project_deployment>/` | `GONGSHO_HOME` | Flat; harness-managed, never hand-edit |
| `bin/`, `run/`, `proxy/`, `templates/`, `tools/` | Checkout | Runtime state + platform code |

`GONGSHO_HOME` defaults to the checkout's parent; `.env` may override.
`apps/` + `data/` are created on first use.

## Ports

| Use | Site | Admin |
|---|---|---|
| Machine Caddy | `:8181` | `127.0.0.1:2019` |
| Scratch/loop checkouts | `8281` | `127.0.0.1:2020` |

Scratch checkouts set `GONGSHO_PORT=8281` plus an admin block in their
Caddyfile and assert both ports free first. Machine ports belong to the
regular runner alone. Unmatched paths return `200` empty; deployment
roots need the trailing slash.

## Toolchains

- **Go:** default caches are sandbox-unwritable; the harness falls back
  to repo-local `.cache/go` automatically. Prefer that over `GOCACHE`
  surgery; `go env -w` to the repo cache is the durable machine fix.
- **Node:** never bare `npm`. UI work runs through vendored pnpm 9:
  verbs call `tools/pnpm` absolutely; interactive shells
  `export PATH="$PWD/tools:$PATH"` from the checkout once per session.
  `tools/cache-warm` provisions pnpm; missing entry means run it.
- **Playwright browsers:** installed per UI project via
  `pnpm exec playwright install --with-deps`; `e2e` defaults
  `PLAYWRIGHT_BROWSERS_PATH` repo-local, explicit settings win.
- **Caddy:** started from the repo checkout
  (`caddy start --config proxy/Caddyfile --adapter caddyfile`); reloads
  follow the config file's admin address, no flags needed.

## Sandboxes

- Writable: the checkout, `/tmp`, git storage. Siblings (`apps/`,
  `data/`) and home dirs need an escalated run or `--yolo`.
- Daemons die with a sandboxed starter: long-lived processes belong in
  a real terminal (Herdr tab), never in an agent shell call.
- Herdr: tabs organize work (`caddy` for the proxy, one per agent);
  the `herdr` skill governs pane/tab control.

## Git

- Never commit, push, tag, amend, or rewrite history without an explicit
  human ask for that exact write. Stage by name, never `add -A` in a
  shared tree.
- Experiment deployments stay local until explicitly released.
- Committed trees: `templates/`, `tools/`, `docs/`. Ignored runtime
  state: `bin/`, `proxy/sockets/`, `proxy/dev.d/`,
  `proxy/deployments/` (derived), `run/`. Inside deployments, `gen/`
  and `src/client` are committed (regen gates keep them honest).
