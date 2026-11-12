# Template: react-ui

Stack: React as a Vite static SPA, TypeScript throughout. Scaffold mirrors the
official Vite `react-ts` template shape plus gongsho wiring.

## Scaffold (`templates/react-ui/app/`, copied to the deployment)

- `package.json` — react, vite, Hey API client dep, Playwright; scripts
  `build`, `build:dev`, `gen-client`, `test-e2e`. Pin exact versions at
  implementation.
- `vite.config.ts` — React plugin; base path supplied per build via the
  `--base` flag (verified Vite behavior), never baked into the file.
- `index.html`, `src/` — entry plus `App` and API callers using the
  generated client. Same-origin calls only; no CORS configuration exists.
- No `openapi-ts.config.ts`: Hey runs via CLI flags from `scripts/gen-client.sh`
  (one run per snapshot spec), which wins over file config for multi-spec
  looping (assumed).
- `src/client/<api-id>/` — generated per snapshot spec, one Hey API run per
  spec (our loop; no multi-input feature assumed). Committed, never
  hand-edited — Hey API's own guidance treats output as a dependency.
- `spec/` — snapshot dir (empty at scaffold; filled by refresh from consumed
  APIs).
- `e2e/` — `playwright.config.ts` plus one example browser flow.
- `.example.env` — comments-only in v1: the UI takes no env vars since API
  paths arrive via `gen-config.json`. Exists so every app has the file.
- `gen-config.json` — runtime config written at deploy from the pin: the API
  paths this UI calls. The app reads it relative to its base (assumed;
  avoids build-time env plumbing). The `gen-` prefix reserves the name to
  the harness so an app-owned `config.json` can never collide.
- `README.md` — scaffold, run, wire, and test commands for Muse.

## Build profiles

- Stable: default production build, hashed assets under a predictable dir
  for the long-cache matcher (assumed rule).
- Dev (E2E): sourcemaps on, minification off (assumed profile; exact flags
  per Vite docs at implementation). Fidelity plus debuggability for
  coverage-mapped runs. Each dev session needs its own build because the
  `--base` value (`/dev/<session>/<path>/`) is baked in at build time;
  stable and dev bundles are never interchangeable.
- Every build regenerates Hey API clients from current snapshots first, so
  stale snapshots fail loudly at the freshness check, never silently.
- Client boot: `setConfig({ baseUrl })` per consumed API from
  `gen-config.json`, behind an async boot gate (load config, configure,
  then render).
