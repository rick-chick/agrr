import { defineConfig, devices } from '@playwright/test';

/**
 * Phase C: 本番 CDN + LB + agrr-production 向けの限定スモーク。
 * - mock ログイン不可（E2E_PRODUCTION=1）
 * - webServer なし（https://agrr.net を直接叩く）
 * - workers=1・単一 spec 実行を想定
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: process.env.CI ? [['html'], ['line']] : 'line',
  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'https://agrr.net',
    locale: 'ja-JP',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'off',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
