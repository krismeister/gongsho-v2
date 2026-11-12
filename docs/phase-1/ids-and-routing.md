# IDs and routing

- Form: team → project → deployments. The underscore ID (`acme_shop_api-1`)
  serves filenames and tags; the slash path (`acme/shop/api-1`) serves URLs,
  trees, and routes. Both are stored in the pin; scaffold validates agreement.
- Charset: segments allow lowercase, digits, and hyphens only, never
  underscores, so the join splits unambiguously. Team `dev` is reserved and
  rejected (it protects the `/dev/` route prefix).
- Derivations are pure functions implemented once in `lib.sh`:
  - ID ↔ path: join/split on `_` (exactly three segments).
  - Trees: `apps/<path>/`, `bin/<path>/`.
  - Proxy file: `proxy/deployments/<id>`; dev file:
    `proxy/dev.d/<session>-<id>`.
  - Socket: `proxy/sockets/<id>.sock`; dev socket:
    `<id>.dev-<session>.sock`; pidfile beside each socket.
- URLs (Caddy on `:8080`, assumed): stable
  `http://localhost:8080/<path>/`; dev
  `http://localhost:8080/dev/<session>/<path>/`.
- No registry in v1: existence checks read the filesystem, listing walks the
  trees, type and version come from pins.
