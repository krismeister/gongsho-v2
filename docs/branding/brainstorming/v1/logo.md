# Logo

Lockup: **wordmark + pod mark**. The mark never appears without the
wordmark except as an avatar or favicon.

## Wordmark

The word `gongsho`, always lowercase, always one word, letterspaced
tight (`-0.02em`). It is typed, not drawn — set it in the display face
(see [Typography](typography.md)) at weight 700. No custom letterforms
to maintain, no font file to embed in the CLI.

```text
gongsho
```

## Pod mark

A horizontal peapod holding three seeds: the request goes in, the
deployment comes out. Three dots read as peas, never eyes.

- Construction: 64-unit grid, capsule `x=4 y=20 w=56 h=24 rx=12`,
  seeds at `(20,32)`, `(32,32)`, `(44,32)`, radius `5.5`.
- Color version: pod in Pod green, seeds in Paper (see
  [Color](color.md)). File:
  [concept-c-peapod.svg](assets/concept-c-peapod.svg).
- Mono version: same geometry in Ink, for single-color use (stamps,
  CLI docs, fax-from-1998 situations). File:
  [concept-c-peapod-mono.svg](assets/concept-c-peapod-mono.svg).
- Playful element, not the logo: the big-headed pea
  ([F](../previews/v10-peapod-bodies.html)) carries the character
  work — hero illustrations, empty states, greetings. It appears
  beside the lockup, never instead of it.

## Lockups

- Horizontal (default): mark left, `gongsho` right, gap of one seed
  diameter. Docs header, README headers, Caddy pages.
- Stacked: mark above, wordmark below. Square spaces (social avatar,
  slide covers).
- Avatar: the peapod centered on Paper, cropped to a circle — keep
  all three seeds clear of the crop.

## Clearspace and size

Clearspace on all sides equals the height of the `o` in the wordmark
(about one seed diameter around the mark). Minimum sizes: mark 16px on
screen / 5mm in print; full lockup 64px wide / 20mm wide. Below that,
use the wordmark alone.

## Misuse

No gradients, shadows, or outlines on the mark. No rotation (pods sit
still). No recoloring outside the palette. No all-caps or camelCase
wordmark. No placing the color mark on photographic or low-contrast
backgrounds — use the mono version on Ink instead.
