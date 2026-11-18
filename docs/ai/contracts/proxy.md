# Proxy (Caddy)

One Caddy terminates a single local port and routes by path prefix. All
directive behavior below follows the Caddy docs cited in `../planning/templates.md` Sources.

## Main Caddyfile (`proxy/Caddyfile`)

```
:8181 {
	import deployments/*
	import dev.d/*

	handle_errors {
		@notfound expression {http.error.status_code} == 404
		handle @notfound {
			rewrite * /404.html
			root * proxy/errors
			file_server
		}
		@badgateway expression {http.error.status_code} == 502
		handle @badgateway {
			rewrite * /502.html
			root * proxy/errors
			file_server
		}
		handle {
			rewrite * /error.html
			root * proxy/errors
			file_server
		}
	}

	handle {
		error 404
	}
}
```

Imports resolve relative to the importing file, and empty globs are safe, so
`dev.d/` may sit empty with zero routes. Caddy loads this file as its config.

## Derivation (stanzas are gitignored)

Files under `proxy/deployments/` are derived, never committed or
hand-edited: every verb re-renders each stanza from the owning template's
`config/caddy/stanza` plus the deployment pin (id, path, `REPO_ROOT`)
before reloading Caddy, so missing or stale files heal instead of
failing. Recreation keys off the template name: `goa-api`,
`langchain-api`, and `react-ui` deployments re-render; unknown template
types are refused loudly. Dev
files under `proxy/dev.d/`
derive from the ensured stable file via the asserted
prefix/socket/root rewrites.

## API stanza (`proxy/deployments/<id>`, rendered from template)

```
handle_path /acme/shop/api-1/* {
    reverse_proxy unix//REPO/proxy/sockets/acme_shop_api-1.sock {
        header_up Host localhost
    }
}
```

- `handle_path` matches the prefix and strips it (assumed): the API sees
  clean paths such as `/users`.
- Unix-socket upstream with an explicit constant `Host localhost` (assumed):
  explicit Host is required for unix upstreams, and Goa doesn't route on
  Host in v1.
- `REPO` renders to the checkout's absolute path at scaffold time. Moving a
  checkout requires re-rendering proxy files (a regen verb covers this later).

## UI stanza (`proxy/deployments/<id>`, rendered from template)

```
handle_path /acme/shop/ui-1/* {
    root * REPO/bin/acme/shop/ui-1
    route {
        try_files {path} /index.html
        header /index.html Cache-Control "public, max-age=0, must-revalidate"
    }
    header /assets/* Cache-Control "public, max-age=31536000, immutable"
    file_server
}
```

- `try_files` serves the real file when it exists and falls back to the
  entry file for client-side routes (assumed).
- The `route` wrapper applies the no-cache header after the fallback rewrite,
  per Caddy's documented directive order.
- Hashed assets need the template emitting them under a predictable dir
  (assumed rule on `react-ui`). Same absolute-path rendering note as above.

## Dev stanzas (`proxy/dev.d/<session>-<id>`)

Same shapes under `/dev/<session>/` with dev sockets and scratch roots,
written temp-then-rename by `dev-up` and removed by `dev-down`, with a Caddy
reload after each change. Logging stays default in v1 (assumed).

## Edge behavior (verified contract)

- The bare `:8181` address carries no hostname, so automatic HTTPS provisions nothing and the server stays plain HTTP on 8181 only (verified with `caddy adapt`). Prefer this over adding hostnames: a hostname-bearing site would need an `http://` prefix to suppress automatic HTTPS.
- Deployment roots require the trailing slash: `/<path>/` proxies, `/<path>`
  does not. Template READMEs must state this.
