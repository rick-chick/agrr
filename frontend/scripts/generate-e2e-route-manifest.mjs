#!/usr/bin/env node
/**
 * src/app/routes/*.routes.ts から path / auth 要否を抽出し、E2E 用 URL 一覧を生成する。
 * 単一の情報源にしてエージェントが「ページを教えて」と聞かないようにする。
 */
import { writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  buildManifestData,
  checkManifestFreshness,
} from './generate-e2e-route-manifest-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND = join(__dirname, '..');
const OUT = join(FRONTEND, 'e2e', 'route-manifest.json');
const ROUTE_TO_PNG = join(FRONTEND, 'e2e', 'agent-review', 'route-to-png.md');

async function writeManifest() {
  const { payload, routeToPngContent } = await buildManifestData(FRONTEND);
  await writeFile(OUT, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  console.log(`wrote ${OUT} (${payload.routes.length} routes)`);
  await writeFile(ROUTE_TO_PNG, routeToPngContent, 'utf8');
  console.log(`wrote ${ROUTE_TO_PNG}`);
}

async function main() {
  if (process.argv.includes('--check')) {
    const { ok, errors } = await checkManifestFreshness(FRONTEND);
    if (!ok) {
      for (const message of errors) {
        console.error(message);
      }
      process.exit(1);
    }
    console.log('route-manifest.json and route-to-png.md are up to date');
    return;
  }

  await writeManifest();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
