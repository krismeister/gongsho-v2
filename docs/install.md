---
title: Install
description: Toolchain, first boot, and verification.
---

## Prerequisites

- Go 1.27.3 or later, Node.js 22 or later, Caddy, `yq`
  (mikefarah's Go yq — `yq --version` must print a
  `github.com/mikefarah/yq` line, not a `jq` line).
- Standard shell tooling: git, curl, bash.

On Arch/Omarchy:

```sh
sudo pacman -S go caddy go-yq nodejs
```

## Clone

```sh
git clone https://github.com/krismeister/gongsho-v2.git
cd gongsho-v2
```

`apps/` and `data/` live beside the checkout (see [Intro](./)) and are
created on first use — nothing to make by hand. Machine config is
optional: copy `.example.env` to `.env` to override host, ports,
timings, or pins; built-in defaults work otherwise.

## Warm caches

```sh
tools/cache-warm
```

Downloads Go modules, compiles the pinned `migrate` binary and goa CLI
entries, and provisions vendored pnpm with prefetched UI dependencies.
Run once per machine (and after any pin bump). Re-runs skip whatever is
already warm — expect `already built` / `already provisioned` lines:

```text
[cache-warm] migrate v4.20.1 already built
[cache-warm] pnpm 9.15.9 already provisioned
```

## Boot

```sh
tools/startup
```

Ensures Caddy is running, re-runs the warmup, then boots every
deployment (builds when stale, starts APIs unless running) and verifies
each through Caddy. Idempotent — safe to run anytime. Ends with:

```text
[startup] startup complete
```

## Verify

```sh
curl http://localhost:8181/
```

Unmatched paths return `200` with an empty body — that empty `200` is
the healthy signal. With deployments present, each serves at
`http://localhost:8181/<team>/<project>/<deployment>/` (trailing slash
required).
