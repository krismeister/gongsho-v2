# Color

Light paper-first. Paper does the work, Ink does the talking, and two
small accents do the playing. Rough ratio: 70 paper / 20 ink / 10 accent.

## Tokens

| Token      | Hex       | Use                                    |
|------------|-----------|----------------------------------------|
| Paper      | `#FAF6EE` | page and card backgrounds              |
| Paper-deep | `#F1EAD9` | borders, wells, code blocks            |
| Line       | `#E3DACA` | hairlines, dividers                    |
| Ink        | `#211C14` | text, mono mark, primary buttons       |
| Ink-soft   | `#5C5546` | secondary text, captions               |
| Pod        | `#2F9E5F` | primary accent, pod mark, links, health ok |
| Signal     | `#E4572E` | errors, destructive actions, rare CTA  |
| Marigold   | `#F0A500` | highlights, badges, second seed — sparing |

CSS variables:

```css
:root {
  --gongsho-paper: #FAF6EE;
  --gongsho-paper-deep: #F1EAD9;
  --gongsho-line: #E3DACA;
  --gongsho-ink: #211C14;
  --gongsho-ink-soft: #5C5546;
  --gongsho-pod: #2F9E5F;
  --gongsho-signal: #E4572E;
  --gongsho-marigold: #F0A500;
}
```

## Pairs that pass

- Ink on Paper — body text (very high contrast, the default).
- Paper on Ink — inverted buttons, footer, CLI banners.
- Paper on Pod — large/bold use only (buttons at 600+, never small body).
- Ink-soft on Paper — secondary text at 14px and up.
- Signal and Marigold are never body-text colors on Paper; use them
  for dots, badges, and borders, with Ink text beside them.

## Dark mode

Invert the base, keep the accents: background `#1B1712`, surface
`#2A241B`, text `#FAF6EE`, secondary `#C9BFAE`. Pod stays `#2F9E5F`
but is used at larger sizes; brighten to `#45B878` only if small Pod
text ever ships (it should not).

## Rules

One accent per surface. Pod is the default; Signal means something
needs attention; Marigold marks something new or delightful. Error
pages may pair Signal with Paper-deep, never Signal on Pod.
