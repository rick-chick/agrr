#!/usr/bin/env node
/**
 * ng serve 用 proxy 設定に undo 復元 API 経路が含まれることを検証する。
 * Angular ユニットテスト（jsdom）の責務外のため scripts で実行する。
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const frontendRoot = join(fileURLToPath(new URL('.', import.meta.url)), '..');
const proxyFiles = ['proxy.conf.dev.cjs', 'proxy.conf.gcp-test.cjs'];
const undoRoutePattern = /['"]\/undo_deletion['"]\s*:/;

let failed = false;

for (const file of proxyFiles) {
  const path = join(frontendRoot, file);
  const content = readFileSync(path, 'utf8');
  if (!undoRoutePattern.test(content)) {
    console.error(`${file}: missing /undo_deletion proxy route`);
    failed = true;
  }
}

if (failed) {
  process.exit(1);
}

console.log('proxy-conf-contract: ok');
