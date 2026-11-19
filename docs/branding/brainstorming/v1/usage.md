# Usage

Where the identity lands. New surfaces adopt it first; existing runtime
output changes only when its surface is redesigned.

## Docs site

Header: horizontal lockup (mark + `gongsho`), Ink on Paper. Links in
Pod green. Code blocks on Paper-deep with Line borders. Keep the
Starlight chrome; reskin with the [Color](color.md) tokens and the
[Typography](typography.md) stacks rather than restyling components.

## CLI

Banner on `create` / boot: lowercase `gongsho` wordmark, one Pod `●`
where color is available, then the concrete route:

```text
gongsho ● http://localhost:8181/<team>/<project>/<deployment>/
```

Health and error output stay Mono, uncolored by default, color opt-in.
Failures report attempt plus exact error plus completed work, per
[Voice](voice.md).

## Caddy pages

Error and 404 pages: Paper background, Ink text, pod mark at 48px, one
sentence in docs voice plus the route attempted. Signal appears only
as a small badge (`404`, `502`), never as the page background.

## Badges and footers

Deployment footer (opt-in for apps): `Built in a gongsho pod ●` in
Ink-soft, linking to the docs site. README badge: Pod dot + `gongsho`
in Mono. No "powered by" lockups imposed on user apps.

## Avatar and favicon

Social avatar and favicon: pod mark centered on Paper, cropped to a
circle (avatar) or rounded square (favicon). Use the mono mark on Ink
where the background cannot be controlled.

## Co-branding

Deployments keep their own names and marks. Gongsho appears at most in
the footer line above. Never prefix deployment names, never recolor a
deployment's UI into the gongsho palette.
