---
name: system-editor
description: Do system-lane work in the gongsho repo: templates, harness, proxy main, and ID rules, under direct human tasking.
---

# Gongsho System Editor

Use for system-lane tasks in this repo: anything under `templates/`, `tools/`,
the main `proxy/Caddyfile`, ID rules, and repo layout itself. Do not use for
project-lane work (deployments under `apps/`, deploys, verifications) — that
follows the normal planner flow.

## First reads

Read these before acting, in order:

- `docs/roadmap.md` — phases, locked decisions, deferred list.
- `docs/phase-1/phase-plan.md` — the build plan and assumed defaults.
- The relevant spec under `docs/phase-1/` for the area touched.

## Rules

- Human-driven: act on system files only under explicit human tasking for that
  change. Otherwise propose the change and stop.
- Never initiate template version bumps, harness rewrites, or ID-rule changes
  on your own, and never start console, packaging, or agent builds — those are
  explicitly held.
- Descriptors: `.gongsho-tpl.yaml` in templates, `.gongsho-deployment.yaml`
  in deployments. Quote versions and timestamps. Template pins are exact.
- Owned versus handed-off: only files listed in a template's `owned` may be
  regenerated across apps. Everything else is app property after scaffold.
- No registry exists: resolve IDs, paths, sockets, and pins by derivation
  from the ID string plus the pin files and the filesystem (see
  `docs/phase-1/ids-and-routing.md`).
- Templates stay compatible with their documented contracts: scaffold shape,
  manifest fields, stanza shapes, health and spec guarantees. Changing a
  contract means updating its spec file in the same change.
- Verify with the harness, never by hand: `template-check` for template work,
  regen-cleanliness for anything generated, `check`/`e2e` for behavior.
- Scratch loops never share the machine ports: any scratch/loop checkout
  runs Caddy on site port 8281 with admin on 127.0.0.1:2020 — scratch
  `.env` sets `GONGSHO_PORT=8281`, scratch `proxy/Caddyfile` carries a
  global `{ admin 127.0.0.1:2020 }` block plus the 8281 site address
  (reloads follow the config file, so no flag changes), and the run
  asserts both ports free before starting. The machine's 8181 and 2019
  belong to the regular runner alone.
- Tasking: instructions in your prompts authorize the files and actions
  they name — don't re-ask permission for those. If two instructions
  conflict, follow the most recent explicit one; if still unclear, ask.
- Thin instructions, clear specs: proceed using judgment and log every
  assumption in your report.
- Full stop only on: conflicts with frozen specs, installs or updates,
  destructive or irreversible actions, or ambiguity between materially
  different outcomes. Report and wait.
