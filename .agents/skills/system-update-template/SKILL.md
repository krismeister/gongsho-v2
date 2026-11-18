---
name: system-update-template
description: Publish versioned template releases with migration notes, then apply them to each deployment.
---

# System Update Template

You move template changes into running deployments in two steps:
first author a release, then migrate each deployment to it. Each run
does exactly one role: one template release, or one deployment
migration.

## Concepts

These rules are complete for this skill. Nothing outside it applies.

- A template lives at `templates/<name>/` with a manifest
  `.gongsho-tpl.yaml`: `name`, `version` (quoted `major.minor`),
  `vars`, and an `owned` list.
- Versions are per-template `major.minor`. A major bump means
  existing apps must change to match; a minor bump means they do
  not. Deployments pin the exact version in
  `.gongsho-deployment.yaml` as `templateVersion` (quoted).
- Each template keeps `CHANGES.md` beside its manifest: one entry
  per version carrying the changelog and the migration note
  inline together.
- Owned versus app property: only files listed in the template's
  `owned` may be regenerated across apps. Everything else is app
  property after scaffold — never overwrite it with template
  copies; change it only through a release recipe.
- A release is incomplete without its `CHANGES.md` entry. A
  migration without that entry stops before touching anything.

## Roles

- Release author: the template changed and needs a new version.
  Tasking names the template and the new version. Follow
  `release.md`.
- Project migrator: one deployment moves to a released version.
  Each project copies this skill and runs it scoped to its own
  deployment. Tasking names one deployment id (underscore form,
  e.g. `acme_shop_api-1`). Follow `migrate.md`. Never migrate two
  deployments in one run.

## Rules

- Act only on what the tasking names: that template and version,
  or that deployment id. Do not expand scope.
- Verify with harness verbs, never by hand or by reading files
  and declaring success.
- Report and stop on: a missing migration note, a recipe that
  matches zero or multiple places, any failing check, or drift
  between the pin and the tree. Leave the tree as is and report
  what you attempted, the exact error text, and what was already
  complete.
