# Combined demo (assumed composition)

One project proving multiplicity: team `demo`, project `shop`.

- `demo_shop_catalog-api` — products list/get over its own SQLite, seeded
  with three products.
- `demo_shop_orders-api` — order create/list over its own SQLite; product
  ids are opaque strings, never cross-DB joins.
- `demo_shop_storefront-ui` — product list from catalog plus an order form
  posting to orders; carries two spec snapshots.

Flows proven, in order: scaffold, build, and deploy all three; UI freshness
checks against both APIs; browser e2e placing an order end to end; kill -9
on an API with proxy-502 plus clean restart recovery; full reset to clean
state. The demo doubles as the living example behind the exit gate: a
fresh-prompt Muse session must reproduce an equivalent triple from READMEs
alone.
