# tools/tests — lib.sh suites

Committed, hermetic tests for `tools/lib.sh`. Every suite derives the repo
root from its own location, builds all fixtures at runtime under a `mktemp -d`
scratch dir (removed by `trap`), and works against fake repos only — the real
`apps/`, `bin/`, `proxy/`, `run/`, and `tools/` trees are never written.

## Run

From the repo root:

```sh
sh tools/tests/run.sh
```

One suite directly:

```sh
sh tools/tests/lib-smoke.sh
```

`run.sh` executes all five suites, prints a combined `suites/pass/fail`
summary, and exits nonzero when any suite fails.

## Suites

- `lib-smoke.sh` — broad lib.sh coverage: derivations, validators, path
  builders, atomic writes, sessions/time, JSON compare, both stanza renders,
  template kinds, transport failures, pidfile stops, pin validation
  (positive + mismatch/missing-db/extra-db negatives), gen-config
  (stable/dev/empty/dangling/malformed), app env + injected vars, dev
  derivation (byte-exact + tamper cases), `need_yq` guard, failure-path
  temp hygiene (failing calls leave no temp files and write no dest).
- `lib-env.sh` — machine config: built-in defaults without `.env`,
  full and partial fake-root `.env` overrides, missing-file silence,
  Go cache fallback (preset/missing/unwritable/writable), GOFLAGS once.
- `lib-probe.sh` — independent battery: pure functions, validation
  accept/reject matrix, path builders, stable renders, empty-gen-config
  placeholder identity, pid helpers, JSON/sha, session minting.
- `lib-probe2.sh` — independent battery against a fake repo: pins and pin
  negatives, non-empty gen-config, app env, live stop, dead-socket reads,
  health negatives plus a live unix-socket health positive (needs python3).
- `lib-probe3.sh` — yq-free paths only: env ensure, live stop, dead-socket
  read. Stays runnable even when yq is broken.
- `lib-probe4.sh` — independent battery: dev derivation positives and
  tamper cases, `need_yq` flavor guard (mikefarah/kislyuk/missing).
- `verbs-cli.sh` — CLI contract for all 15 verbs: `--help`, usage errors,
  unknown deployments, hermetic state failures. No toolchains run.
- `verbs-ops.sh` — hermetic operational positives: create/retire/refresh
  with a stub caddy, dev-up/dev-down, UI check/status, API
  start/status/check/restart/stop via a python fake binary, migrate
  backup/prune/restore via a go-stub emulator (real migrate proven in
  scratch). Python-gated blocks SKIP without python3.

## Fixtures

Static fixtures live in `fixtures/`. The current suites need none: every
fixture (fake repos, pins, snapshots, pidfiles, expected bytes) is generated
at runtime under scratch, so the directory holds only `.gitkeep`.
