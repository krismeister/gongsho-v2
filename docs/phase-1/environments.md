# Environments

Two levels, never mixed. Machine config lives in the repo-root `.env`;
per-app tunables live in each deployment's `.env`. Both files are
gitignored; only `.example.env` files are committed.

## Machine `.env` (repo root)

Read by `tools/lib.sh` on every verb invocation when present; silent
when absent. Each key has a built-in default — env wins, defaults
apply otherwise. The `GONGSHO_` prefix keeps machine config from
leaking into app runtimes (the file is sourced with exports):

- `GONGSHO_HOST` / `GONGSHO_PORT` / `GONGSHO_SCHEME` (default
  `localhost` / `8181` / `http`) — compose `CADDY_ORIGIN`.
- `GONGSHO_START_HEALTH_TIMEOUT` / `GONGSHO_STOP_GRACE` (default
  `10` / `5`, seconds) — supervisor timings.
- `GONGSHO_MIGRATE_VERSION` (default `v4.20.1`) — golang-migrate pin.
- `CADDY_STORAGE` (unset by default) — override only when the Caddy
  default store is not writable.

Scratch/loop checkouts never use these values (see the port rule in
`e2e-standard.md`).

## App `.env` (per deployment)

Launch verbs ensure it exists (copy from `.example.env` on first
need), source it for tunables, then export the pin-derived injected
set over it: `SOCKET_PATH`, `DB_PATH`, `DEPLOYMENT_ID`,
`TEMPLATE`, `TEMPLATE_VERSION`. Injected always wins; the app reads
env only. UI `.example.env` files carry no keys (API addresses arrive
via `gen-config.json`); the file still exists so every app has one.

## Go toolchain (machine-level fallback)

`lib.sh` probes the default Go cache for writability and falls back
to repo-local `.cache/go` (gitignored) when sandboxed sessions cannot
write it, logging one line. It also appends `-buildvcs=false` to
`GOFLAGS`: checkouts carrying both `.git` and sandbox `.hg` stubs
make Go builds fail on VCS stamping otherwise. Both are no-ops when
defaults work.
