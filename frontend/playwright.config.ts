import { defineConfig, devices } from '@playwright/test';

const useDevSession = !!process.env.E2E_CAPTURE_DEV_SESSION;

const ngServe = {
  command: 'npx ng serve --host 127.0.0.1 --port 4200 --configuration development',
  url: 'http://127.0.0.1:4200',
  reuseExistingServer: !process.env.CI,
  timeout: 180_000,
  stdout: 'pipe' as const,
  stderr: 'pipe' as const,
};

/**
 * E2E: ルート妥当性検証 + Agent レビュー用 PNG（ピクセル回帰はしない）。
 *
 * - `route-manifest-visual.spec.ts` は **`npm run e2e:capture-for-agent`** が付与する `E2E_CAPTURE_DEV_SESSION=1` のときのみ実行（それ以外は skip）。
 * - Mock login: **agrr-server** `GET /auth/test/mock_login_as/{user}`（既定: ng serve :4200 proxy → :3000）。
 * - `E2E_CAPTURE_DEV_SESSION=1`: 事前に `./dev-docker/scripts/host-rust-stack.sh`（:3000 strangler → agrr-server）。
 * - `getApiBaseUrl()` は同一オリジン（`proxySameOriginApi`）で ''。
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  /** Agent 用フルページ PNG は並列で `Page.captureScreenshot` が失敗し得るため 1 ワーカーに固定 */
  workers: useDevSession ? 1 : process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [['html'], ['line']] : 'html',
  ...(useDevSession ? { globalSetup: './e2e/global-setup-dev-session.ts' } : {}),
  use: {
    baseURL: 'http://127.0.0.1:4200',
    locale: 'ja-JP',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'off',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        ...(useDevSession ? { storageState: 'e2e/.auth/dev-session.json' } : {}),
      },
    },
  ],
  webServer: ngServe,
});
