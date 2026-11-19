# Gongsho

A pod-based application development platform: templates first, then
gongsho-console, then gongsho-apps.

Docs (GitHub Pages): https://krismeister.github.io/gongsho-v2/

Status: templates and harness are built and green; planning docs live
in `docs/`.

## Prerequisites

- Go 1.27.3 or later, Node.js 22 or later, Caddy, yq
  (mikefarah's Go yq — `yq --version` must print a
  `github.com/mikefarah/yq` line, not a `jq` line; the Python `yq`
  wrapper is a different tool and will not work).
- Playwright browsers install per UI project
  (`pnpm exec playwright install --with-deps`, with the harness pnpm on
  `PATH` per the UI template README).
- Standard shell tooling: git, curl, bash.

Omarchy/Arch install for the toolchain:

```sh
sudo pacman -S go caddy go-yq nodejs
```

(`go-yq` is the Arch package for mikefarah yq; it replaces/conflicts
with the Python `yq` package. If `yq` is already installed, pacman
offers the replacement during install.)

## Docs

Read in order:

- `docs/index.md` — what gongsho is and where to go next.
- `docs/install.md` — toolchain, first boot, verification.
- `docs/skills.md` — which agent does what.
- `docs/planning/roadmap.md` — direction, durable decisions, and the
  canonical deferred list.
- `docs/planning/templates.md` — how the templates effort was built.
- `docs/ai/` — agent entry, runbook, and frozen contracts.

## Layout

Two roots: the checkout holds `templates/` (scaffold sources), `tools/`
(the `.sh` harness), `proxy/` (Caddy config, sockets), `bin/` (build
output), `run/` (dev scratch), and `docs/`; deployments and databases
live beside it in `apps/` and `data/`. See `docs/index.md` for the map.
