import { defineConfig, devices } from '@playwright/test';
import { join } from 'node:path';

const repoRoot = join(process.cwd(), '..');
const useDevSession = !!process.env.E2E_CAPTURE_DEV_SESSION;

const ngServe = {
  command: 'npx ng serve --host 127.0.0.1 --port 4200 --configuration development',
  url: 'http://127.0.0.1:4200',
  reuseExistingServer: !process.env.CI,
  timeout: 180_000,
  stdout: 'pipe' as const,
  stderr: 'pipe' as const,
};

/** Rails development + mock_login。E2E_CAPTURE_DEV_SESSION=1 のときのみ。 */
const railsDev = {
  command:
    'FRONTEND_URL=http://127.0.0.1:4200,http://localhost:4200 bundle exec rails server -b 127.0.0.1 -p 3000 -e development',
  url: 'http://127.0.0.1:3000/up',
  cwd: repoRoot,
  reuseExistingServer: !process.env.CI,
  timeout: 180_000,
  stdout: 'pipe' as const,
  stderr: 'pipe' as const,
};

/**
 * E2E: ルート妥当性検証 + Agent レビュー用 PNG（ピクセル回帰はしない）。
 *
 * - `route-manifest-visual.spec.ts` は **`npm run e2e:capture-for-agent`** が付与する `E2E_CAPTURE_DEV_SESSION=1` のときのみ実行（それ以外は skip）。
 * - `E2E_CAPTURE_DEV_SESSION=1`: Rails development を起動し、globalSetup が AuthTestController のモックログインで実セッションを書き出す。
 *   `getApiBaseUrl()` が 127.0.0.1:4200 → 127.0.0.1:3000 を向ける前提。
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
  webServer: useDevSession ? [railsDev, ngServe] : ngServe,
});
