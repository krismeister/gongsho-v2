# Migrations and databases

- One SQLite database per API, path from the deployment pin (`db.path`,
  repo-root-relative). UIs have no database.
- Tool: golang-migrate, invoked as an explicit harness step (`migrate`
  verb, version pinned in `tools/`), never on boot. Migration files live
  app-owned under `apps/<id>/migrations/` as up/down pairs; constants ride
  the first migration. The tool keeps its version table inside each DB.
- Mint and fresh deploy: create empty file, migrate from zero (no backup
  possible, nothing to protect).
- Dev scratch: migrate up, no backup (disposable by design).
- Stable promotion: copy the DB to a timestamped backup, migrate up, verify
  by reading back the version, prune all but three backups (assumed). On
  failure: restore the backup over the partial result and abort the deploy
  loudly. File-level restore beats down-migrations for SQLite.
- `gen/` stays committed and must regenerate with no diff; the DSL remains
  the contract and migrations stay hand-authored app code, never generated.
