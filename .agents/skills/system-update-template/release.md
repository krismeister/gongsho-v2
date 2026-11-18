# Release author

You publish one new version of one template. Tasking names the
template and the new version.

## Steps

1. Read the template manifest `templates/<name>/.gongsho-tpl.yaml`
   and record the current quoted version.
2. Diff the template against the current version. Describe every
   change since that version in plain words: what changed and why.
   This description is the changelog; it ships with the release.
3. Classify each change:
   - owned-only: touches only `owned` files, apps pick it up by
     regeneration, no app edits needed;
   - app-code-required: a convention, shape, or contract changed
     and deployments must edit their own code or config to match;
   - no-action: comments, docs, or scaffolding for new apps only.
4. Check the bump: any app-code-required change means the new
   version must be major. A major bump with no app-code-required
   change is suspect — flag it and wait.
5. Write the migration note. One note per release, kept with the
   template, covering:
   - the from → to versions;
   - per-deployment steps in order: what regenerates, what to
     hand-edit, what verifies success;
   - the recipe for every app-code-required change: an exact
     before/after snippet or a script, plus how to find each
     occurrence.
6. If a changed behavior is part of the template's contract
   (scaffold shape, manifest fields, health or spec guarantees),
   update the template's own README or contract text in the same
   change.
7. Bump the quoted `version` in `.gongsho-tpl.yaml`.
8. Run the harness template check for this template. Green alone
   completes the release.

## Stop

Stop and report instead of publishing when the version is already
taken, a change cannot be classified, a recipe has no reliable
matcher, or the template check fails.
