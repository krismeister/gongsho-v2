# E2E standard

Every run is hermetic: mint a fresh session, build what's needed, verify
through Caddy as a client would, report, tear down always. Failed runs
preserve scratch and print its location; successes clean fully.

## Environment contract (assumed names)

The verb exports, and specs never hardcode addresses:

- `E2E_BASE_URL` — session root, e.g. `http://localhost:8181/dev/a3f9`.
- `E2E_APP_<IDSLUG>` — one full URL per deployment under test (ID uppercased,
  e.g. `E2E_APP_ACME_SHOP_API_1=http://localhost:8181/dev/a3f9/acme/shop/api-1`).
- `E2E_ARTIFACTS_DIR` — screenshots, traces, coverage reports land here.

## Runners (per template)

- APIs: `go test ./e2e/` with stdlib HTTP client plus testify (`require` for
  setup, `assert` for flows) against the `/dev/` route — testing prefix
  behavior too, not just handlers.
- UIs: Playwright Test, config `playwright.config.ts` with specs under
  `e2e/`, headless across browsers; coverage collected on the Chromium run
  via the Coverage API and converted to a line-level report in artifacts.
  Browsers provision with `npx playwright install --with-deps` as a
  documented prerequisite.

## Callers

ui-dev routinely per change, planner as the cross-stack integration gate,
api-dev only when proxy-path behavior is under test, human on demand. No
caller shares sessions; isolation is structural, not polite.
