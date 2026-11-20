# react-ui changes

## 1.1 — 2026-11-20 (from 1.0)
### Changes
- [no-action] Favicon defaults for new scaffolds: `public/` now ships `icon.svg`, `favicon.ico` (16/32/48 ICO), and `apple-touch-icon.png` (180x180 opaque), adapted from the light peapod mark (plum `#9d276c`, white seeds); `index.html` links all three with root-absolute hrefs that Vite rebases per deployment `--base`. Existing deployments build and serve exactly as before.
### Migrate from 1.0
No action required: 1.0 bundles keep building and serving unchanged. To adopt the favicon on an existing deployment:
1. Copy the three favicon files from the template into the deployment's `public/` dir.
   Recipe: from the checkout run `cp -- templates/react-ui/app/public/icon.svg templates/react-ui/app/public/favicon.ico templates/react-ui/app/public/apple-touch-icon.png apps/<path>/public/`.
   Matcher: exactly these three filenames; if any already exists under the app's `public/`, stop and report instead of overwriting.
2. Link them in the app's `index.html` head directly after the viewport meta.
   Recipe before (must match exactly once):
   `    <meta name="viewport" content="width=device-width, initial-scale=1.0" />`
   Recipe after: that line followed by
   `    <link rel="icon" type="image/svg+xml" href="/icon.svg" />`
   `    <link rel="alternate icon" href="/favicon.ico" sizes="any" />`
   `    <link rel="apple-touch-icon" href="/apple-touch-icon.png" />`
   Matcher: the viewport line occurs exactly once in `index.html`; the three link lines occur zero times before.
3. Update the pin and verify.
   Recipe: set `templateVersion: "1.1"` (quoted) in the deployment's `.gongsho-deployment.yaml`; then from the checkout run `tools/deploy <id>` (builds, swaps the bundle, verifies through Caddy) and `tools/check <id>`. Both must pass.
