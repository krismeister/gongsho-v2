# Gongsho brand standard

The files in `logo/`, `mark/`, and `pages/` are the standard. Earlier
exploration lives in [brainstorming/v1/](brainstorming/v1/) and is not
current.

## Mark and logo

- [Light mark](mark/gongsho-mark-light.svg) — peapod in deep plum
  `#9d276c`, white seeds. [Dark mark](mark/gongsho-mark-dark.svg) —
  peapod in bright pink `#f45ea1`, seeds in paper `#f5f1e7`.
- [Light logo](logo/gongsho-logo-light.svg) — outlined wordmark
  "Gongsho" in ink navy `#152a3d`, mark alongside.
  [Dark logo](logo/gongsho-logo-dark.svg) — wordmark in paper
  `#f5f1e7`.
- The `pages/` files inline the logo as base64: edit the source SVGs
  in `logo/` first, then re-embed.

## Pages

- [Light page](pages/gongsho-light.html) and [dark
  page](pages/gongsho-dark.html) — same copy, same structure.
- Palette: paper with a faint dot grid; light ink `#152a3d` /
  dark ink `#f5f1e7` on navy `#131e2a` with a teal top-light.
  Accent is the pod pink (plum `#9d276c` on light,
  `#f45da1`/`#f45ea1` on dark); success green is secondary.
- Signature treatments: rotated marker-swipe highlights behind key
  words, a ledger-style spec table, and the striding pea mascot in
  the hero. Tagline: "Give your ideas a place to run."
- Highlight washes are specified as overlays, not solids, because the
  background shows through: light page pink `rgb(196 61 139 / 22%)`
  and green `rgb(70 183 125 / 26%)`; dark page pink
  `rgb(250 106 168 / 48%)` and green `rgb(96 198 143 / 46%)`.
  Re-tune the alpha per surface — never lift a wash value from one
  background onto another and expect the same color.

## App theme

[shadcn theme](theme/shadcn.css) — the standard as light + dark
design tokens (oklch) for shadcn/Tailwind v4. A
[green-primary variant](theme/shadcn-green.css) swaps the lead role
to the success green when pink gets too loud. Primary is the pod
plum/pink, secondary the pink wash, accent the success green, charts
extend to the CLI teal, output blue, and prompt pink. Paste it into
tweakcn's editor (Import → CSS) or drop it into `globals.css`.

## Tone and preferences

Business users, wonder over cleverness. Agent-forward ("tell an
agent what you're building"), plain verbs, concrete nouns — URLs,
templates, health checks. Playful pods, boring promises: the pea and
the markers carry the warmth, claims about reliability stay checkable.
Prefer light surfaces with one luminous moment over dark-everything,
and one accent per surface.
