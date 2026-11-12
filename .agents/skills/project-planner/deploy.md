# Verify (deploy order plus checks)

Order: every API, then every UI. (Automatic when phases run in order.)

If Caddy is down, nothing verifies. Check and start:

```sh
curl -s http://localhost:8181/ > /dev/null || caddy start --config proxy/Caddyfile --adapter caddyfile
```

Per API (bodies must match exactly):

```sh
curl http://localhost:8181/acme/shop/api-1/healthz
curl http://localhost:8181/acme/shop/api-1/info
```

Per UI (trailing slash required):

```sh
curl http://localhost:8181/acme/shop/ui-1/
```

Assert response bodies, not just status: unmatched paths return 200
with an empty body.

Report: each deployment URL plus its check result. That report ends
the job.
