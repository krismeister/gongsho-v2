# API phase (per API)

Work in `apps/<team>/<project>/<deployment>/`.

1. Write the schema in `design/` (Goa DSL).
2. Generate and normalize:

```sh
go run goa.design/goa/v3/cmd/goa gen $(go list -m)/design
cp gen/http/openapi3.json gen/openapi.json
```

`gen/` is output: change `design/` and re-run step 2 to change it.
3. Implement `service/` to match.
4. Each schema change rides a new up/down migration pair in
   `migrations/`; the first pair exists from scaffold.
5. Deploy and fix forward from its output:

```sh
tools/deploy acme_shop_api-1
```

6. Confirm `gen/openapi.json` exists. That file is the UI handoff.
