---
title: Skills
description: Which agent does what, and when to invoke each.
---

Gongsho has two agent skills. Full texts live in `.agents/skills/`;
this page is the map.

## project-planning-basic — builds deployments

Turns a request into running deployments, doing the work itself: design
(API-first, then UIs), one `create` per deployment, implement each API
(schema, gen, service, migrations) then each UI (snapshots, clients,
screens), deploy in order, verify through Caddy, report URLs.

- **Invoke it** to build anything: a new app, a new deployment, a feature.
- **Needs from you first:** team and project names. Nothing else starts
  without them.
- **Works in** `../apps/<team>/<project>/<deployment>/` (sibling tree);
  runs verbs from the repo checkout. Stops on any error and reports
  attempt plus exact error plus completed work.
- **Knows:** the two-root layout, UI shell setup
  (`export PATH="$PWD/tools:$PATH"` for vendored pnpm), deploy order.

## system-editor — owns the platform

Does system-lane work under direct human tasking: `templates/`,
`tools/`, the main `proxy/Caddyfile`, ID rules, repo layout, and specs.
Refuses on its own: template version bumps, harness rewrites, ID-rule
changes, console/packaging/agent builds.

- **Invoke it** to change the platform itself (not deployments).
- **Reads first:** roadmap, templates record, then the contract for the area touched.
- **Knows:** the two roots (`GONGSHO_HOME` vs checkout), owned-vs-handed-off
  template artifacts, verify-with-the-harness (never by hand), scratch
  ports 8281/2020, hermetic test conventions.

## Which one?

Building or changing an **app** → planner. Changing **templates, tools,
proxy, IDs, or specs** → system editor. If unsure, the planner stops and
asks rather than guessing across the lane line.
