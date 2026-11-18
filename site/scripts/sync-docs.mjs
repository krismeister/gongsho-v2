// Sync the published pages from the canonical repo docs into Starlight's
// content dir. Explicit file list: nothing publishes by accident.
// Usage: node ./scripts/sync-docs.mjs (also runs as part of build/dev).
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = join(root, '..', 'docs');
const dest = join(root, 'src', 'content', 'docs');

// [source relative to docs/, dest relative to content docs]
const pages = [
  ['index.md', 'index.md'],
  ['install.md', 'install.md'],
  ['skills.md', 'skills.md'],
  ['ai/README.md', 'ai/index.md'],
  ['ai/runbook.md', 'ai/runbook.md'],
];

function withFrontmatter(text, fallback) {
  if (text.startsWith('---\n')) return text;
  const h1 = text.match(/^#\s+(.+)$/m);
  const title = h1 ? h1[1].trim() : fallback;
  return `---\ntitle: ${title}\n---\n\n${text}`;
}

rmSync(dest, { recursive: true, force: true });
for (const [from, to] of pages) {
  const srcFile = join(src, from);
  if (!existsSync(srcFile)) {
    console.error(`sync-docs: missing source docs/${from}`);
    process.exit(1);
  }
  const destFile = join(dest, to);
  mkdirSync(dirname(destFile), { recursive: true });
  const fallback = to.replace(/\.md$/, '').split('/').pop();
  writeFileSync(destFile, withFrontmatter(readFileSync(srcFile, 'utf8'), fallback));
  console.log(`sync-docs: docs/${from} -> ${to}`);
}
