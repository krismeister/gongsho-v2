# Repository layout

Two roots. `GONGSHO_HOME` (default: parent of the checkout) holds the
persistent trees; the repo checkout holds platform code plus regenerable
runtime state. `(c)` committed, `(g)` gitignored, `*` created per deployment.

```
$GONGSHO_HOME/
├── gongsho_v2/ (this repo)
│   ├── README.md (c)
│   ├── docs/ (c)
│   │   ├── roadmap.md
│   │   ├── agent-workflow-usecase-1.md
│   │   └── phase-1/ (phase-plan.md plus this folder's detail specs)
│   ├── templates/ (c)
│   │   ├── goa-api/
│   │   │   ├── .gongsho-tpl.yaml
│   │   │   ├── config/ (caddy/stanza, defaults, health spec)
│   │   │   ├── app/ (design/, service skeleton, migrations/, e2e/, config, README)
│   │   │   └── README.md
│   │   └── react-ui/ (same shape: scaffold, e2e/, README)
│   ├── bin/<team>/<project>/<deployment>/ (g) * (deep: Caddy serves one
│   │   folder per deployment via root + try_files + cache split)
│   ├── proxy/
│   │   ├── Caddyfile (c)
│   │   ├── deployments/ (g) * (derived: re-rendered from template plus pin)
│   │   ├── dev.d/ (g)
│   │   └── sockets/ (g) (sockets plus pidfiles)
│   ├── run/ (g) (per-session scratch)
│   └── tools/ (c) (*.sh verbs, lib.sh wrapper plus lib/ modules, tests/
│       suites; bin/ (g) prebuilt helper binaries)
├── apps/<team>/<project>/<deployment>/ * (deep agent working area)
└── data/<team_project_deployment>/ (`app.db` per API) * (flat)
```

Rules:

- Source committed: `templates/`, `tools/`, `docs/`.
  `apps/` lives outside the repo and is never committed from here.
- Runtime and disposable ignored: `bin/`, `proxy/sockets/`,
  `proxy/dev.d/`, `proxy/deployments/`, `run/`. Database files live under `$GONGSHO_HOME/data/`,
  created by create and deploy via migrate.
- Generated-but-committed (reviewable diffs; regen gates keep them honest):
  `gen/` inside APIs, `src/client` inside UIs.
