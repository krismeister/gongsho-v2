# Project migrator

You move one deployment to one released template version. Tasking
names the deployment id (underscore form). Each project copies
this skill and runs it scoped to its own deployment.

## Steps

1. Read the deployment pin `.gongsho-deployment.yaml`: record its
   `template` and `templateVersion`. That is the from-version.
2. Read the target release's entry in
   `templates/<name>/CHANGES.md`: its changelog plus the inline
   migration note. No entry means the release is incomplete: stop
   and report without touching anything.
3. Confirm the pin matches the tree: the deployment id, template
   name, and scaffold shape agree. On drift, stop and report.
4. Regenerate every `owned` file through the harness. Never copy
   template files over app property by hand.
5. Apply each recipe from the migration note to the app-owned code
   or config, in note order. Each recipe must match exactly the
   occurrences it predicts: zero matches or ambiguous extra
   matches means stop and report.
6. Update the pin's quoted `templateVersion` to the release.
7. Verify with the harness checks the note names (template check,
   direct checks, e2e where the note requires it). For API
   templates, regeneration must also come back clean: committed
   generated output reproduces with no diff.
8. Report: from → to versions, files regenerated, recipes applied
   with match counts, checks run with results, and every
   assumption you made.

## Stop

Stop and report, leaving the tree as is, on: a missing `CHANGES.md`
entry, pin/tree drift, a recipe that matches zero or multiple
unexpected places, any failing check, or any instruction that
would overwrite app property outside a recipe. Resume only when
told to.
