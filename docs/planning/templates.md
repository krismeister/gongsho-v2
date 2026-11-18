# Templates effort (complete)

How gongsho got its templates, harness, and routing: goal, what was
built, the stack decisions, and the assumed defaults that were accepted
as-built. For the machine contracts, see `../ai/contracts/`; for what
comes next, see `roadmap.md`.

## Goal (achieved)

Deliver `goa-api` and `react-ui` templates plus a `.sh` harness such
that a fresh-prompt session can scaffold, build, deploy, verify, and
tear down deployments with no tribal knowledge — proven by a combined
demo project running two APIs and one UI off one localhost Caddy.

## What exists now

- `templates/goa-api/` — Goa design-first API: `design/` contract,
  service skeleton, migrations, e2e, `gen/` committed and regen-clean,
  OpenAPI served at a stable route, unix-socket listen, health spec.
- `templates/react-ui/` — Vite static SPA: parameterized base, Hey API
  client generation from `spec/` snapshots, one browser flow, static
  bundle with hashed assets.
- `tools/` — one verb per file over shared `lib.sh`: create, build,
  deploy, check, e2e, refresh-spec, dev-up/down, start/stop/restart/
  status, retire, migrate, cache-warm, startup, install, pnpm, plus
  system-lane `template-check`. Every verb has `--help`, explicit args,
  and machine-readable exit codes.
- Routing: one Caddy on `:8181`, deployments by path prefix, dev routes
  under `/dev/<session>/`, stanzas re-rendered from template plus pin.
- Combined demo: two APIs plus one consuming UI (see `demo.md`).

## Stack decisions

- API stack is Goa (design DSL in, servers plus OpenAPI out), HTTP/JSON
  only; oapi-codegen and ogen rejected as HTTP-only.
- UI stack is React as a Vite static SPA; no BFF (serving is proxy
  config). A future `nextjs-ui` template stays separate, never a mode flag.
- Subpath serving via Vite `base`; TS clients via Hey API from pinned
  snapshots (exact 0.x pin; openapi-typescript is the fallback).
- Proxy is Caddy (prefix-strip proxying, glob imports, graceful reload);
  nginx and Traefik rejected as heavier per-route config. UI stanzas
  follow Caddy's documented SPA pattern (root, try_files, file server,
  split cache headers).
- DB is SQLite per API (single file: backup is a copy); libSQL evaluated
  and rejected as unneeded surface. Migrations via golang-migrate
  (pinned), goose second choice.
- API e2e is `go test` plus testify; UI e2e is Playwright across
  Chromium/Firefox/WebKit.
- No queue (all flows synchronous), no registry (IDs derive from pins
  plus filesystem), pidfile supervision behind per-deployment verbs.

## Assumed defaults (all accepted as built)

Port `:8181`; strip API prefixes; constant Host; UI fallback plus cache
split; default Caddy logging; `.sh` harness; `create` name; `retire`
in v1; `template-new` skipped; bumps later; `dev-up` routes-only with
e2e building bundles; empty `vars` kept; deployment dirs flat once
scaffolded; app config Muse-editable; proxy files re-rendered
(derived, ignored); scratch under `run/`; HTTP/JSON-only transports;
pins plus driver plus socket verification at implementation;
compiler-plus-regen strictness only; TanStack later; constants via first
migrations; prune-to-three backups; migrate pin in `tools/`; go module
path convention; `app.env` config; `/healthz` shape; `/openapi.json`
route; E2E env names; Hey per-spec loop with committed output; atomic
`bin/` promotion; `*.db` ignored; dev bundle profile (maps on, minify
off); demo composition; retire archives data alongside; backup suffix
`.bak-<timestamp>`; api binary named `api`; `http://` site scheme;
trailing-slash rule; injected env set
(`DB_PATH`, `SOCKET_PATH`, `DEPLOYMENT_ID`, `TEMPLATE`,
`TEMPLATE_VERSION`); Hey flags win over config file; `.example.env`
replaces `app.env`; UI `.example.env` comments-only; `/info` serves id
plus template plus version; `GONGSHO_*` machine keys; scratch ports
8281/2020; Go-cache fallback plus `-buildvcs=false`; tidy self-heals
scaffolds (no pin-fidelity byte-compare per the staleness rule).

## Sources

- https://caddyserver.com/docs/caddyfile/directives/reverse_proxy
- https://caddyserver.com/docs/caddyfile/directives/import
- https://caddyserver.com/docs/command-line
- https://caddyserver.com/docs/caddyfile/patterns
- https://caddyserver.com/docs/caddyfile/directives/header
- https://caddyserver.com/docs/caddyfile/directives/file_server
- https://caddyserver.com/docs/caddyfile/directives/root
- https://caddyserver.com/docs/caddyfile/directives/try_files
- https://www.sqlite.org/about.html
- https://kubernetes.io/docs/concepts/storage/volumes/
- https://arxiv.org/html/2506.06251v1
- https://goa.design/
- https://goa.design/docs/
- https://github.com/oapi-codegen/oapi-codegen
- https://github.com/ogen-go/ogen
- https://vite.dev/guide/build
- https://heyapi.dev/openapi-ts/get-started.html
- https://registry.npmjs.org/@hey-api%2Fopenapi-ts/latest
- https://registry.npmjs.org/openapi-typescript/latest
- https://playwright.dev/
- https://raw.githubusercontent.com/stretchr/testify/master/README.md
- https://pkg.go.dev/net/http/httptest
- https://github.com/golang-migrate/migrate
- https://github.com/pressly/goose
- https://github.com/mikefarah/yq
