import { defineConfig, devices } from '@playwright/test';

/**
 * Static research HTML under public/ — no ng serve or API required.
 * Serves from repo public/ via serve-research-local.py on :8775.
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
    baseURL: 'http://127.0.0.1:8775',
    locale: 'ja-JP',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'python3 .cursor/skills/research-tools/scripts/serve-research-local.py --port 8775',
    cwd: '..',
    url: 'http://127.0.0.1:8775/research/',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
