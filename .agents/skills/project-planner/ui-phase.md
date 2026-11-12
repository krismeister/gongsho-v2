# UI phase (per UI)

Work in `apps/<team>/<project>/<deployment>/`.

1. Per consumed API:

```sh
tools/refresh-spec acme_shop_ui-1 acme_shop_api-1
```

2. Regenerate clients:

```sh
npm run gen-client
```

(`src/client/` is output: re-run this to change it.)
3. Wire each client in `src/lib/boot.ts` (same pattern as the
   deployment README's Wiring section):

```ts
import { client as shopApi } from '../client/acme_shop_api-1/client.gen';
shopApi.setConfig({ baseUrl: config.apis['acme_shop_api-1'] });
```

4. Build the screens against the typed clients. Read API addresses
   only from the runtime config; they arrive at deploy time.
5. Deploy:

```sh
tools/deploy acme_shop_ui-1
```
