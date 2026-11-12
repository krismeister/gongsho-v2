import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, devices } from '@playwright/test';

// E2E env contract (docs/phase-1/e2e-standard.md): the harness exports
// E2E_BASE_URL, E2E_APP_<IDSLUG> per deployment under test, and
// E2E_ARTIFACTS_DIR. This config never hardcodes addresses.
const rootDir = dirname(fileURLToPath(import.meta.url));

function withTrailingSlash(url: string): string {
  return url.endsWith('/') ? url : `${url}/`;
}

function resolveBaseURL(): string | undefined {
  const pinPath = join(rootDir, '.gongsho-deployment.yaml');
  if (existsSync(pinPath)) {
    const id = readFileSync(pinPath, 'utf8').match(/^id:\s*(\S+)\s*$/m)?.[1];
    if (id === undefined) throw new Error(`e2e: no id found in ${pinPath}`);
    // Slug per e2e-standard: ID uppercased, hyphens to underscores
    // (hyphens are not valid in env var names).
    const slug = id.toUpperCase().replace(/-/g, '_');
    const url = process.env[`E2E_APP_${slug}`];
    if (url === undefined || url === '') {
      throw new Error(`e2e: missing E2E_APP_${slug} for deployment ${id}`);
    }
    return withTrailingSlash(url);
  }
  // No pin: template scaffold or standalone run. E2E_BASE_URL works when
  // set; otherwise baseURL stays undefined so `playwright test --list`
  // still validates the config, and real runs fail at navigation.
  const base = process.env.E2E_BASE_URL;
  return base === undefined || base === '' ? undefined : withTrailingSlash(base);
}

export default defineConfig({
  testDir: './e2e',
  outputDir: process.env.E2E_ARTIFACTS_DIR ?? './test-results',
  use: {
    baseURL: resolveBaseURL(),
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
});
