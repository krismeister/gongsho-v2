# Spec handoff (API to UI)

- Emission: each API build normalizes its generated OpenAPI to
  `apps/<api>/gen/openapi.json` and serves it at a stable route. Generated
  truth, never a second dictation.
- Snapshots: each UI keeps `apps/<ui>/spec/<api-id>.openapi.json`, one file
  per consumed API. Presence declares consumption; each UI upgrades
  independently, so one API serves many UIs at mixed versions.
- Freshness: every UI build byte-compares each snapshot against the API's
  current spec and fails on drift, naming the API, both hashes, and the
  refresh command. New API versions never silently reach a UI.
- Refresh is the explicit `refresh-spec` verb only — copy current over
  snapshot, then re-run UI checks plus e2e. Never automatic.
- Missing spec (API never generated) and dangling snapshot (API gone) both
  fail with actionable messages. Multi-backend design beyond this stays
  deferred per the roadmap.
