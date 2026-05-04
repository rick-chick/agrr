import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { HOST_SELECTOR_BY_PATTERN } from './route-validity';

/**
 * ルート追加時、route-manifest とホストセレクタ表のズレがないこと（PNG 妥当性の前提）。
 */
test('route-manifest の各 pattern に route-validity のホストが定義されている', () => {
  const manifest = JSON.parse(
    readFileSync(join(process.cwd(), 'e2e/route-manifest.json'), 'utf8'),
  ) as { routes: Array<{ pattern: string }> };

  const missing: string[] = [];
  for (const r of manifest.routes) {
    if (!HOST_SELECTOR_BY_PATTERN[r.pattern]) {
      missing.push(r.pattern);
    }
  }
  expect(missing, `HOST_SELECTOR_BY_PATTERN 未設定: ${missing.join(', ')}`).toEqual([]);
});
