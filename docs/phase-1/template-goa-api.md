# Template: goa-api

Stack: Goa per your choice, HTTP/JSON transports only in v1 (assumed).
Go 1.27.3 or later and `go install goa.design/goa/v3/cmd/goa@v3.35.0` per the
Goa quickstart at time of writing; pin exact versions at implementation.

## Scaffold (`templates/goa-api/app/`, copied to the deployment)

- `design/design.go` — example service plus method in Goa DSL shape:
  `Service` containing `Method` with `Payload`, `Result`, and an `HTTP`
  block (`GET("/...")`). The app's contract lives here, owned by the app.
- `go.mod` — module `gongsho/<team>/<project>/<deployment>`, derived from
  the ID (assumed convention; never imported externally).
- `service/` — implementation skeleton behind the generated interfaces.
- `migrations/0001_init.<up,down>.sql` — constants-first migration as an
  up/down pair (golang-migrate file convention).
- `e2e/e2e_test.go` — one HTTP flow test via `E2E_BASE_URL`, testify
  `require` for setup and `assert` for flow checks.
- `app.env` — `KEY=VALUE` runtime config: socket path, db path, log level
  (assumed format; read with plain env handling, no YAML in the app).
- `main.go` — entrypoint: open DB, serve the Goa server on the unix socket.
- `README.md` — scaffold, run, wire, and test commands for Muse.

## Generation and guarantees

- `go run goa.design/goa/v3/cmd/goa gen <module>/design` regenerates;
  `gen/` is committed and must regenerate with no diff (regen-cleanliness).
- Build normalizes the emitted OpenAPI to `gen/openapi.json` and serves it
  at `GET /openapi.json` (assumed route).
- Health: `GET /healthz` returns 200 plus `{"status":"ok"}` (assumed shape).
- The server listens on its unix socket (acceptance criterion: verify at
  implementation; loopback-TCP fallback documented in phase-plan Risks).
