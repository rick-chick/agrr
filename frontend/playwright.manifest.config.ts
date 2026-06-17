import { defineConfig } from '@playwright/test';

/**
 * route-manifest-coverage のみ実行。ng serve / API 不要（ファイル突合のみ）。
 */
export default defineConfig({
  testDir: './e2e',
  testMatch: 'route-manifest-coverage.spec.ts',
  forbidOnly: !!process.env.CI,
  reporter: process.env.CI ? 'line' : 'list'
});
