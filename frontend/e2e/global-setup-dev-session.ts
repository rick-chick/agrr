import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { request, type FullConfig } from '@playwright/test';

/**
 * E2E_CAPTURE_DEV_SESSION=1 のときのみ実行。
 * agrr-server（Rust）の `/auth/test/mock_login_as/{user}` で session cookie を付与し、
 * 全テストで共有する storage state を書き出す（既定: ng serve :4200 proxy → :3000 → :8080）。
 *
 * ブラウザでフロントへリダイレクト完了まで待たない（Angular 未起動でも Cookie は同一レスポンスで付く）。
 * 事前起動: `./scripts/dev-rust-stack.sh` + Playwright `E2E_STRANGLER=1`。
 */
export default async function globalSetup(config: FullConfig): Promise<void> {
  if (!process.env.E2E_CAPTURE_DEV_SESSION) {
    return;
  }

  const authDir = join(process.cwd(), 'e2e', '.auth');
  const statePath = join(authDir, 'dev-session.json');
  mkdirSync(authDir, { recursive: true });

  const baseURL = (config.projects[0]?.use?.baseURL as string | undefined)?.replace(/\/$/, '') ?? 'http://127.0.0.1:4200';
  const apiOrigin = (process.env.E2E_API_ORIGIN ?? baseURL).replace(/\/$/, '');
  const returnTo = `${baseURL}/`;

  const apiRequest = await request.newContext({ baseURL: apiOrigin });
  try {
    const loginPath = `/auth/test/mock_login_as/developer?return_to=${encodeURIComponent(returnTo)}`;
    const resp = await apiRequest.get(loginPath, { maxRedirects: 0, timeout: 120_000 });
    if (![302, 303, 307].includes(resp.status())) {
      const body = await resp.text();
      throw new Error(`mock_login expected 302/303/307, got ${resp.status()}: ${body.slice(0, 500)}`);
    }
    await apiRequest.storageState({ path: statePath });
  } finally {
    await apiRequest.dispose();
  }
}
