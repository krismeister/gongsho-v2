# Supervision and runtime

## Process lifecycle (pidfile supervisor, per deployment)

- `start`: refuse if the pidfile names a live process; unlink any stale
  socket; ensure `.env` exists (copy from `.example.env` if missing), source
  it, then export resolved `DB_PATH`/`SOCKET_PATH`/`DEPLOYMENT_ID`/`TEMPLATE`/
  `TEMPLATE_VERSION` (all pin-derived, per instance) and launch detached;
  record the pid; wait on
  health with a timeout (assumed: 10s) and roll back the start on timeout.
- `stop`: SIGTERM, 5s grace (assumed), then SIGKILL; remove the pidfile on a
  clean stop.
- `restart`: stop plus start as one verb (brief 502 window accepted, no
  draining in v1).
- `status`: pid alive plus endpoint health in one report. Pids live beside
  sockets in `proxy/sockets/`.
- Recovery from `kill -9` is `restart`: stale socket unlinked, fresh process,
  same verification as a deploy restart.

## Runtime layout

- Sockets and pidfiles: `proxy/sockets/<id>.sock`, `<id>.pid`; dev copies
  take `.dev-<session>` infixes. Directory is gitignored.
- `bin/` promotion is atomic: build into `<path>.new`, rename over the old
  output (assumed). Caddy never serves a half-written tree.
- `run/<session>/` holds dev DBs and dev bundles (assumed location); `dev-down`
  removes it, except e2e failures preserve scratch and print its path.
- Health probes hit the socket directly for lifecycle checks (e.g. curl's
  unix-socket mode) and go through Caddy for deploy verification, proving
  the full path.
