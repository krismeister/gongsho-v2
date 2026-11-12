# Template: react-ui (v1.0)

React as a Vite static SPA, TypeScript throughout. Scaffold mirrors the
official Vite `react-ts` template shape plus gongsho wiring. SPA-only: no
server rendering (a future `nextjs-ui` template covers that).

## Layout

- `.gongsho-tpl.yaml` — manifest: `vars: [id]`, `owned: [proxy-stanza]`.
- `config/caddy/stanza` — proxy stanza template; render `${PATH}` (slash
  path, e.g. `acme/shop/ui-1`) and `${REPO}` (absolute checkout path).
  Verbatim shape from `docs/phase-1/proxy.md`.
- `app/` — scaffold source, copied as-is to the deployment dir.

Only `proxy-stanza` may be regenerated across apps; everything under `app/`
is app property after scaffold.

## Scaffold (Muse)

`create <path> --template react-ui` copies `app/` to `apps/<path>/` and
writes `.gongsho-deployment.yaml` beside it (harness-owned). Then:

```sh
cd apps/<path>
npm install
npm run build -- --base=/<path>/
```

Raw scaffold builds green with zero snapshots: `gen-client` no-ops and the
shell renders a "no APIs" state. Wire APIs via `refresh-spec`, then rebuild.

## Contracts for the harness

- **Build:** `npm run build -- --base=/<path>/` (stable) and
  `npm run build:dev -- --base=/dev/<session>/<path>/` (e2e profile:
  sourcemaps on, minify off). Both regen clients, typecheck, and emit
  `dist/` with hashed assets under `assets/` (stock Vite dir, matches the
  proxy long-cache matcher). Promotion to `bin/` is the harness's job.
- **gen-client:** one `openapi-ts -i/-o` run per `spec/*.openapi.json`
  (flags need `./`-prefixed local paths); exit 0 on empty `spec/`; prunes
  client dirs whose snapshot is gone. There is no `openapi-ts.config.ts`
  by design: CLI flags from the script are the single mechanism.
- **Freshness (harness-side):** every build byte-compares each snapshot
  against the API's current spec and fails on drift, naming the API, both
  hashes, and the refresh command.
- **gen-config.json:** deploy writes the API map from the pin plus the `spec/`
  listing (`<api-id>` -> `/<api-path>`) either to `public/gen-config.json`
  before building (stock Vite carries it into the bundle and serves it in
  dev, overwriting the scaffold placeholder) or directly to the bundle root
  after building. The app fetches `<base>/gen-config.json` at runtime.
  The `gen-` prefix reserves the name to the harness; apps remain free to
  own a plain `config.json` of their own.
- **E2E:** `npm run test-e2e` (Playwright across Chromium/Firefox/WebKit).
  `playwright.config.ts` reads the deployment id from the pin and uses
  `E2E_APP_<IDSLUG>`; artifacts go to `E2E_ARTIFACTS_DIR`. Without a pin
  it falls back to `E2E_BASE_URL`, and with neither env var the config
  still loads (so `--list` validates it) while real runs fail at
  navigation. Specs: `e2e/`.

## Guarantees

Static bundle; hashed assets under `assets/`; same-origin API calls only
(baseUrl values are absolute paths from gen-config.json); generated clients
are byte-deterministic and committed, never hand-edited.

## Pins (exact, resolved from registry.npmjs.org)

| Package | Version | Note |
|---|---|---|
| react / react-dom | 19.3.1 | latest |
| vite | 8.3.8 | latest; engines `^20.19.0 \|\| >=22.12.0` |
| @vitejs/plugin-react | 6.3.0 | latest |
| typescript | 5.9.3 | latest 5.x; 0.99.0 crashes on TS 7 |
| @hey-api/openapi-ts | 0.99.0 | latest; engines `>=22.18.0` sets the Node floor |
| @hey-api/client-fetch | 0.13.1 | latest; scaffold status caller |
| @playwright/test | 1.65.0 | latest; provides `playwright` CLI |
| @types/react / @types/react-dom | 19.3.0 | match React 19 |
| @types/node | 26.6.6 | latest; config/e2e types |
| node floor | >=22.18.0 | from Hey API engines (covers Vite/Playwright) |

No lockfile ships: exact pins in `package.json` are the pin mechanism.
