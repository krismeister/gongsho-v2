# Templates

## goa-api — backend API with its own SQLite

Every backend is one of these. Own database, no sharing across APIs.

```sh
tools/create acme/shop/api-1 --template goa-api
```

You get `design/` (the contract you write), `service/` (your code),
`migrations/`, `e2e/`, plus `gen/` after generation.

## react-ui — user interface

Every frontend is one of these. Static page, calls APIs same-origin.

```sh
tools/create acme/shop/ui-1 --template react-ui
```

You get the app plus empty `spec/`. It calls nothing until Phase 4
fills `spec/` and wires clients.

## Combining them

One API serves many UIs; one UI consumes many APIs. Each UI pins its
own copy of each API spec and upgrades only when you refresh it.
