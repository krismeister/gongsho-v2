# Typography

Three jobs, three faces. The CLI never loads a font file; product and
docs share the same stacks.

## Faces

- Display / wordmark: **Space Grotesk**, 700, `-0.02em`. Dev-credible,
  slightly technical; the wordmark and page titles live here.
- Body / UI: **Inter**, 400/500/600. Everything humans read at length.
- Code / CLI / paths: **JetBrains Mono**, 400/600. Commands, IDs,
  routes (`<team>/<project>/<deployment>`), health output.

Fallback stacks (offline, CLI, no webfonts):

```css
--font-display: "Space Grotesk", "Avenir Next", "Segoe UI", sans-serif;
--font-body: "Inter", system-ui, -apple-system, "Segoe UI", sans-serif;
--font-mono: "JetBrains Mono", ui-monospace, "Cascadia Mono", Menlo, monospace;
```

## Rules

- Page titles in Display 700; never set body copy in Display.
- Wordmark is Display 700 lowercase with tight tracking — typed, per
  [Logo](logo.md), never bolded Inter.
- IDs, ports (`:8181`), and commands stay in Mono, even inside prose.
- CLI banners use plain weight and case rules instead of fonts: the
  `gongsho` wordmark in lowercase, section headers in uppercase, and
  one Pod-green dot (`●`) as the only decoration where color is
  available. No ASCII-art pods.
- Line length 60–75 characters for docs body; code blocks wrap never.
