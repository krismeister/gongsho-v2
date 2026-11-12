# Gongsho

A pod-based application development platform, built in three phases:
templates first, then gongsho-console, then gongsho-apps.

Status: Phase 1 is in detailed design. Planning docs live in `docs/`;
no implementation exists yet.

## Prerequisites

- Go 1.27.3 or later, Node.js 22 or later, Caddy, yq.
- Playwright browsers install per UI project
  (`npx playwright install --with-deps`).
- Standard shell tooling: git, curl, bash.

Omarchy/Arch install for the toolchain:

```sh
sudo pacman -S go caddy yq nodejs
```

## Docs

Read in order:

- `docs/roadmap.md` — overall phases, locked decisions, and the
  canonical deferred-decisions list.
- `docs/phase-1/phase-plan.md` — detailed Phase 1 plan: both templates, the
  harness, deployment configuration, and the combined demo.
- `docs/agent-workflow-usecase-1.md` — triage: how any human message
  becomes an answer, an edit, or a question.

## Planned layout

Per the Phase 1 plan: `templates/` (scaffold sources), `tools/` (the
`.sh` harness), `apps/` (deployment source), `bin/` (build output),
`proxy/` (Caddy config, sockets), `run/` (dev scratch). See
`docs/phase-1/phase-plan.md` for the full tree.
