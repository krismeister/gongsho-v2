---
title: Gongsho
description: A pod-based application platform.
template: splash
hero:
  tagline: Design, scaffold, and deploy apps through agents and a boring shell harness.
  actions:
    - text: Install
      link: ./install/
      icon: right-arrow
    - text: Skills map
      link: ./skills/
      icon: puzzle
---

## What it is

Gongsho turns a request into running deployments: API and UI templates,
a `.sh` harness (`tools/`) that scaffolds, builds, deploys, and verifies
them, and one Caddy that routes every deployment by path prefix.

## The shape

Two roots. The repo checkout holds platform code plus regenerable
runtime state; deployments and databases live beside it:

```text
~/dev/gongsho/             # GONGSHO_HOME
├── gongsho_v2/           # this repo: tools, templates, proxy, docs
├── apps/<team>/<project>/<deployment>/   # deployment source
└── data/<team_project_deployment>/       # SQLite per API
```

One Caddy on `:8181` serves `http://localhost:8181/<team>/<project>/<deployment>/`.

## Where next

- [Install](./install/) — toolchain, first boot, verify it serves.
- [Skills](./skills/) — which agent does what, and when to invoke each.
- [Agent docs](./ai/) — frozen contracts and machine runbook (for agents).
