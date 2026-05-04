import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { request, type FullConfig } from '@playwright/test';

/**
 * E2E_CAPTURE_DEV_SESSION=1 のときのみ実行。
 * development の AuthTestController モックログインで session cookie を付与し、
 * 全テストで共有する storage state を書き出す。
 *
 * ブラウザでフロントへリダイレクト完了まで待たない（Angular 未起動・FRONTEND_URL と return_to の
 * 組み合わせで外れる・reuseExistingServer で別 env の Rails が動いている等でも Cookie は同一レスポンスで付く）。
 */
export default async function globalSetup(config: FullConfig): Promise<void> {
  if (!process.env.E2E_CAPTURE_DEV_SESSION) {
    return;
  }

  const authDir = join(process.cwd(), 'e2e', '.auth');
  const statePath = join(authDir, 'dev-session.json');
  mkdirSync(authDir, { recursive: true });

  const baseURL = (config.projects[0]?.use?.baseURL as string | undefined)?.replace(/\/$/, '') ?? 'http://127.0.0.1:4200';
  const apiOrigin = (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:3000').replace(/\/$/, '');
  const returnTo = `${baseURL}/`;

  const apiRequest = await request.newContext({ baseURL: apiOrigin });
  try {
    const loginPath = `/auth/test/mock_login_as/developer?return_to=${encodeURIComponent(returnTo)}`;
    const resp = await apiRequest.get(loginPath, { maxRedirects: 0, timeout: 120_000 });
    if (resp.status() !== 302) {
      const body = await resp.text();
      throw new Error(`mock_login expected 302, got ${resp.status()}: ${body.slice(0, 500)}`);
    }
    await apiRequest.storageState({ path: statePath });
  } finally {
    await apiRequest.dispose();
  }
}
