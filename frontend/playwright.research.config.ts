import { defineConfig, devices } from '@playwright/test';

/**
 * Static research HTML under public/ — no ng serve or API required.
 * Serves from repo public/ on :8765 (matches issue #457 repro steps).
 */
export default defineConfig({
  testDir: './e2e/smoke',
  testMatch: 'research-cta-smoke.spec.ts',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: process.env.CI ? [['line']] : 'list',
  use: {
    baseURL: 'http://127.0.0.1:8765',
    locale: 'ja-JP',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'python3 -m http.server 8765',
    cwd: '../public',
    url: 'http://127.0.0.1:8765',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
