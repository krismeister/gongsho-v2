---
title: Agent docs
description: Entry point for coding agents working in this repo.
---

You are an agent acting in the gongsho repo. Read in this order:

1. [Runbook](./runbook/) — roots, ports, toolchains, sandboxes. Non-negotiable facts.
2. The skill for your lane: `project-planning-basic` (build deployments)
   or `system-editor` (change the platform). The skill names its own
   first reads; follow them.
3. Contracts below as your task requires them.

## Frozen contracts (read, never reinterpret)

All live in `docs/ai/contracts/`:

- Descriptors (both YAML schemas), IDs and routing (charset,
  derivations, URLs), E2E environment (contract + runners), proxy
  shapes (main file, stanzas, edge behavior), tools and flows (verbs,
  `lib.sh`, tests), spec handoff (snapshots, drift, refresh),
  template contracts (`template-goa-api`, `template-react-ui`).

## Standing rules

- `GONGSHO_HOME` (default: checkout's parent) holds `apps/` and `data/`;
  `bin/`, `run/`, `proxy/`, `templates/`, `tools/` stay in the checkout.
- Never commit or push without an explicit human ask. Never commit
  experiment deployments or their proxy stanzas.
- Verify with the harness (`tools/tests/run.sh`, `check`/`e2e`,
  `template-check`), never by hand-waving. Stop on any error with
  attempt plus exact error plus completed work.
