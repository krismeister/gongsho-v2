import { expect, test } from '@playwright/test';

// Example browser flow: the shell renders and the deploy-written runtime
// config is served beside the bundle. Per-API behavior specs build on this.
test('shell renders and serves runtime config', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Gongsho UI' })).toBeVisible();
  await expect(page.getByTestId('api-status')).toBeVisible();
  const res = await page.request.get('gen-config.json');
  expect(res.ok()).toBe(true);
});
