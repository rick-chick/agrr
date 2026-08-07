#!/usr/bin/env node
/**
 * コンポーネント CSS に残った「生の色指定」を列挙する（styles.css のトークン方針への当て漏れ検知）。
 * トークン定義ファイルは対象外。
 *
 * var(...) 内のフォールバック直書き色も enforce 対象とする。
 *
 * 使い方:
 *   node scripts/audit-component-css-tokens.mjs           # レポートのみ（exit 0）
 *   node scripts/audit-component-css-tokens.mjs --enforce # var 外またはフォールバック直書き色が 1 件でも exit 1（CI 用）
 */
import { readdir, readFile } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

import { findViolations, shouldEnforceFail } from './audit-component-css-tokens-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND_ROOT = join(__dirname, '..');
const COMPONENTS_CSS_ROOT = join(FRONTEND_ROOT, 'src/app/components');

const ENFORCE = process.argv.includes('--enforce');

async function* walkCssFiles(dir) {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const ent of entries) {
    const p = join(dir, ent.name);
    if (ent.isDirectory()) {
      yield* walkCssFiles(p);
    } else if (ent.isFile() && ent.name.endsWith('.css')) {
      yield p;
    }
  }
}

async function main() {
  const allOutside = [];
  const allInside = [];
  for await (const abs of walkCssFiles(COMPONENTS_CSS_ROOT)) {
    const rel = relative(FRONTEND_ROOT, abs);
    const raw = await readFile(abs, 'utf8');
    const { outside, insideVar } = findViolations(raw);
    for (const v of outside) {
      allOutside.push({ file: rel, ...v });
    }
    for (const v of insideVar) {
      allInside.push({ file: rel, ...v });
    }
  }

  const sortFn = (a, b) => (a.file + a.line).localeCompare(b.file + b.line);
  allOutside.sort(sortFn);
  allInside.sort(sortFn);

  const total = allOutside.length + allInside.length;

  if (total === 0) {
    console.log('audit-component-css-tokens: 違反なし（components 配下）');
    process.exit(0);
  }

  console.error(
    `audit-component-css-tokens: var 外の生色指定 ${allOutside.length} 件 | var 内フォールバック ${allInside.length} 件（いずれも enforce 対象） | 計 ${total} 件\n`,
  );

  if (allOutside.length > 0) {
    console.error('--- var 外（トークン置換の主対象） ---\n');
    for (const v of allOutside) {
      console.error(`${v.file}:${v.line}  [${v.kind}] ${v.value}`);
      console.error(`  ${v.snippet}\n`);
    }
  }

  if (allInside.length > 0) {
    console.error('--- var(...) 内フォールバック直書き色（enforce 対象） ---\n');
    for (const v of allInside) {
      console.error(`${v.file}:${v.line}  [${v.kind}] ${v.value}`);
      console.error(`  ${v.snippet}\n`);
    }
  }

  if (shouldEnforceFail(allOutside.length, allInside.length, ENFORCE)) {
    process.exit(1);
  }
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
