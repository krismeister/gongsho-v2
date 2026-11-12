# AGENTS.md

Gongsho `react-ui` deployment: a Vite static SPA (React + TypeScript).
You are working in the deployment dir, and it is your whole world: every
path and command below lives inside it. Scaffold/run/wire detail: `README.md`.

## Commands (this dir)

- `npm install`, `npm run dev`
- `npm run build -- --base=/<team>/<project>/<deployment>/` (stable bundle)
- `npm run build:dev -- --base=/dev/<session>/<team>/<project>/<deployment>/` (e2e bundle)
- `npm run gen-client`, `npm run test-e2e`

## Contracts

- Runtime config: deploy writes `public/gen-config.json` (`{apis: {id: /path}}`);
  the app fetches `<base>/gen-config.json` at boot. Never bake API addresses
  into code, and never write `public/gen-config.json` by hand.
- Snapshots: `spec/<api-id>.openapi.json`, written by the harness only —
  never hand-write them. Every build regens the Hey API clients in
  `src/client/` from them.
- Same-origin API calls only. No CORS configuration exists.
- E2E: Playwright across Chromium/Firefox/WebKit; base URL resolves from
  `E2E_APP_<IDSLUG>` / `E2E_BASE_URL`, artifacts to `E2E_ARTIFACTS_DIR`.

## Never touch

- `.gongsho-deployment.yaml` (harness-owned pin)
- `src/client/` (generated; regen with `npm run gen-client`, never edit)

## Detail

`README.md` in this dir.
