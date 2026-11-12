# Repository layout

Full tree. `(c)` committed, `(g)` gitignored, `*` created per deployment.

```
.
├── README.md (c)
├── docs/ (c)
│   ├── roadmap.md
│   ├── agent-workflow-usecase-1.md
│   └── phase-1/ (phase-plan.md plus this folder's detail specs)
├── templates/ (c)
│   ├── goa-api/
│   │   ├── .gongsho-tpl.yaml
│   │   ├── config/ (caddy/stanza, defaults, health spec)
│   │   ├── app/ (design/, service skeleton, migrations/, e2e/, config, README)
│   │   └── README.md
│   └── react-ui/ (same shape: scaffold, e2e/, README)
├── apps/<team>/<project>/<deployment>/ (c) *
├── bin/<team>/<project>/<deployment>/ (g) *
├── data/<team>/<project>/<deployment>/ (g) (`app.db` per API) *
├── proxy/
│   ├── Caddyfile (c)
│   ├── deployments/ (c in v1)
│   ├── dev.d/ (g)
│   └── sockets/ (g) (sockets plus pidfiles)
├── run/ (g) (per-session scratch)
└── tools/ (c) (*.sh verbs plus lib.sh)
```

Rules:

- Source committed: `apps/`, `templates/`, `tools/`, `proxy/deployments/`, `docs/`.
- Runtime and disposable ignored: `bin/`, `data/`, `proxy/sockets/`,
  `proxy/dev.d/`, `run/`. Database files live under `data/`, created by mint
  and deploy via migrate.
- Generated-but-committed (reviewable diffs; regen gates keep them honest):
  `gen/` inside APIs, `src/client` inside UIs.
