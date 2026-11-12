# App (gongsho react-ui deployment)

Vite static SPA (React + TypeScript). Same-origin API calls only — there is
no CORS configuration anywhere. API addresses come from the deploy-written
`public/gen-config.json`, never from build-time env.

## Prerequisites

- Node.js >= 22.18.0 (`engines` enforces this).
- For browser e2e: `npx playwright install --with-deps` (one-time).

## Commands

```sh
npm install
npm run dev                        # local dev server (root base)
npm run build -- --base=/team/project/dep/     # stable bundle -> dist/
npm run build:dev -- --base=/dev/<s>/team/project/dep/  # e2e bundle: sourcemaps on, minify off
npm run gen-client                 # regen Hey API clients from spec/ snapshots
npm run test-e2e                   # Playwright (needs e2e env, see below)
npm run preview                    # serve dist/ locally (root base only)
```

Both builds regen clients first, then typecheck (`tsc -b`), then bundle.
`--base` is always passed per build; it is never baked into `vite.config.ts`.

## Wiring an API

1. `refresh-spec <ui-id> <api-id>` copies the API's current OpenAPI into
   `spec/<api-id>.openapi.json`. Presence declares consumption.
2. `npm run gen-client` generates `src/client/<api-id>/` (one Hey API run
   per snapshot). Never hand-edit generated output.
3. Join the boot gate in `src/lib/boot.ts`: `setConfig({ baseUrl })` the
   generated client from config before anything renders:

```ts
// inside boot(), after configureApiClients(config):
import { client as shopApi } from '../client/acme_shop_api-1/client.gen';
shopApi.setConfig({ baseUrl: config.apis['acme_shop_api-1'] });
```

   Then use the typed SDK from any feature module (all render post-boot):

```ts
import { listWidgets } from '../client/acme_shop_api-1';
const { data, error } = await listWidgets();
```

4. Deploy writes `public/gen-config.json` from the pin before building
   (overwriting the `{"apis": {}}` placeholder that ships in scaffold):

```json
{ "apis": { "acme_shop_api-1": "/acme/shop/api-1" } }
```

Each UI upgrades independently: a new API version never reaches this UI
until refresh-spec copies it, and builds fail on snapshot drift.

## E2E

`playwright.config.ts` resolves its base URL from the e2e env contract: it
reads the deployment id from `.gongsho-deployment.yaml` and uses
`E2E_APP_<IDSLUG>` (uppercased id), falling back to `E2E_BASE_URL` when no
pin exists. Artifacts go to `E2E_ARTIFACTS_DIR` (default `./test-results`).
Example flow: `e2e/app.spec.ts`.

## Notes

- TypeScript is pinned to the 5 line (5.9.3): `@hey-api/openapi-ts@0.99.0`
  crashes at startup on TypeScript 7's native API.
- `openapi-typescript` is the documented fallback generator (not wired).
- `src/client/` output is byte-deterministic: regen must produce no diff.
