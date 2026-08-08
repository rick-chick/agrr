import { join } from 'node:path';
import { request, type APIRequestContext } from '@playwright/test';
import {
  E2E_EMPTY_MOCK_USER,
  writeEmptyStateSession,
} from './empty-state-session-lib.mjs';
import {
  ensureFarmWithoutFields,
  resetEmptyStateUserData,
} from './empty-state-seed-lib.mjs';

export type EmptyStateScenario = 'farms-zero' | 'plans-zero' | 'crops-zero' | 'farm-no-fields';

export { E2E_EMPTY_MOCK_USER };
export { resetEmptyStateUserData, ensureFarmWithoutFields };

export function emptyStateSessionPath(): string {
  return join(process.cwd(), 'e2e', '.auth', 'e2e-empty-session.json');
}

function apiOrigin(): string {
  return (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:4200').replace(/\/$/, '');
}

function baseUrl(): string {
  return (process.env.PLAYWRIGHT_BASE_URL ?? 'http://127.0.0.1:4200').replace(/\/$/, '');
}

/** mock_login_as/e2e_empty で storage state を生成する（globalSetup でも同ファイルを書く）。 */
export async function ensureEmptyStateSession(): Promise<string> {
  const authDir = join(process.cwd(), 'e2e', '.auth');
  return writeEmptyStateSession({
    apiOrigin: apiOrigin(),
    returnTo: `${baseUrl()}/`,
    authDir,
  });
}

export async function createEmptyStateApiContext(): Promise<APIRequestContext> {
  const statePath = await ensureEmptyStateSession();
  return request.newContext({ storageState: statePath, baseURL: apiOrigin() });
}

/** シナリオごとに DB を整えてからページ遷移する。 */
export async function prepareEmptyStateScenario(
  scenario: EmptyStateScenario,
): Promise<void> {
  const api = await createEmptyStateApiContext();
  try {
    const base = apiOrigin();
    if (scenario === 'farm-no-fields') {
      await ensureFarmWithoutFields(api, base);
    } else {
      await resetEmptyStateUserData(api, base);
    }
  } finally {
    await api.dispose();
  }
}
