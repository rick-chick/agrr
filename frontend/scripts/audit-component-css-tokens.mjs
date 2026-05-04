#!/usr/bin/env node
/**
 * コンポーネント CSS に残った「生の色指定」を列挙する（styles.css のトークン方針への当て漏れ検知）。
 * トークン定義ファイルは対象外。
 *
 * 使い方:
 *   node scripts/audit-component-css-tokens.mjs           # レポートのみ（exit 0）
 *   node scripts/audit-component-css-tokens.mjs --enforce   # 1 件でも exit 1（CI 用）
 */
import { readdir, readFile } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND_ROOT = join(__dirname, '..');
const COMPONENTS_CSS_ROOT = join(FRONTEND_ROOT, 'src/app/components');

const HEX_RE = /#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b/g;
const RGB_RE = /\brgba?\([^)]*\)/g;

const ENFORCE = process.argv.includes('--enforce');

function stripBlockComments(text) {
  return text.replace(/\/\*[\s\S]*?\*\//g, '\n');
}

function stripLineComments(line) {
  const idx = line.indexOf('//');
  if (idx === -1) return line;
  const before = line.slice(0, idx);
  const qSingle = (before.match(/'/g) || []).length;
  const qDouble = (before.match(/"/g) || []).length;
  if (qSingle % 2 === 1 || qDouble % 2 === 1) return line;
  return before;
}

function maskUrls(fragment) {
  return fragment.replace(/url\([^)]*\)/gi, 'url()');
}

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

function findViolations(raw) {
  const stripped = stripBlockComments(raw);
  const lines = stripped.split(/\n/);
  const out = [];

  for (let i = 0; i < lines.length; i++) {
    let line = stripLineComments(lines[i]);
    line = maskUrls(line);
    if (!line.includes('#') && !line.toLowerCase().includes('rgb')) continue;

    let m;
    const seen = new Set();
    HEX_RE.lastIndex = 0;
    while ((m = HEX_RE.exec(line)) !== null) {
      const key = `hex:${i + 1}:${m.index}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({
        line: i + 1,
        kind: 'hex',
        value: m[0],
        snippet: line.trim().slice(0, 120),
      });
    }
    RGB_RE.lastIndex = 0;
    while ((m = RGB_RE.exec(line)) !== null) {
      const key = `rgb:${i + 1}:${m.index}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({
        line: i + 1,
        kind: 'rgb',
        value: m[0].trim(),
        snippet: line.trim().slice(0, 120),
      });
    }
  }
  return out;
}

async function main() {
  const all = [];
  for await (const abs of walkCssFiles(COMPONENTS_CSS_ROOT)) {
    const rel = relative(FRONTEND_ROOT, abs);
    const raw = await readFile(abs, 'utf8');
    const violations = findViolations(raw);
    for (const v of violations) {
      all.push({ file: rel, ...v });
    }
  }

  all.sort((a, b) => (a.file + a.line).localeCompare(b.file + b.line));

  if (all.length === 0) {
    console.log('audit-component-css-tokens: 違反なし（components 配下）');
    process.exit(0);
  }

  console.error(`audit-component-css-tokens: ${all.length} 件（var(--…) ではない生の色指定の疑い）\n`);
  for (const v of all) {
    console.error(`${v.file}:${v.line}  [${v.kind}] ${v.value}`);
    console.error(`  ${v.snippet}\n`);
  }

  if (ENFORCE) {
    process.exit(1);
  }
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
