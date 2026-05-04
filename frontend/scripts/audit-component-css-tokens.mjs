#!/usr/bin/env node
/**
 * コンポーネント CSS に残った「生の色指定」を列挙する（styles.css のトークン方針への当て漏れ検知）。
 * トークン定義ファイルは対象外。
 *
 * var(...) 内（フォールバック含む）は別カウントし、enforce は「var 外のみ」を対象にする。
 *
 * 使い方:
 *   node scripts/audit-component-css-tokens.mjs           # レポートのみ（exit 0）
 *   node scripts/audit-component-css-tokens.mjs --enforce # var 外が 1 件でも exit 1（CI 用）
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

/** @returns {[number, number][]} inclusive start, exclusive end */
function findVarSpans(line) {
  const spans = [];
  const lower = line.toLowerCase();
  let i = 0;
  while (i < line.length) {
    const idx = lower.indexOf('var(', i);
    if (idx === -1) break;
    let j = idx + 4;
    let depth = 1;
    while (j < line.length && depth > 0) {
      const c = line[j];
      if (c === '(') depth++;
      else if (c === ')') depth--;
      j++;
    }
    spans.push([idx, j]);
    i = j;
  }
  return spans;
}

function isInsideVarSpans(index, spans) {
  return spans.some(([a, b]) => index >= a && index < b);
}

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

/**
 * @param {string} line
 * @param {number} lineNumber 1-based
 * @returns {{ outside: object[], insideVar: object[] }}
 */
function findViolationsInLine(line, lineNumber) {
  const spans = findVarSpans(line);
  const outside = [];
  const insideVar = [];

  const pushMatch = (kind, value, index, snippetSource) => {
    const row = {
      line: lineNumber,
      kind,
      value,
      snippet: snippetSource.trim().slice(0, 120),
    };
    if (isInsideVarSpans(index, spans)) insideVar.push(row);
    else outside.push(row);
  };

  let m;
  const seenHex = new Set();
  HEX_RE.lastIndex = 0;
  while ((m = HEX_RE.exec(line)) !== null) {
    const key = `hex:${lineNumber}:${m.index}`;
    if (seenHex.has(key)) continue;
    seenHex.add(key);
    pushMatch('hex', m[0], m.index, line);
  }

  const seenRgb = new Set();
  RGB_RE.lastIndex = 0;
  while ((m = RGB_RE.exec(line)) !== null) {
    const key = `rgb:${lineNumber}:${m.index}`;
    if (seenRgb.has(key)) continue;
    seenRgb.add(key);
    pushMatch('rgb', m[0].trim(), m.index, line);
  }

  return { outside, insideVar };
}

function findViolations(raw) {
  const stripped = stripBlockComments(raw);
  const lines = stripped.split(/\n/);
  const outside = [];
  const insideVar = [];

  for (let i = 0; i < lines.length; i++) {
    let line = stripLineComments(lines[i]);
    line = maskUrls(line);
    if (!line.includes('#') && !line.toLowerCase().includes('rgb')) continue;

    const { outside: o, insideVar: iv } = findViolationsInLine(line, i + 1);
    outside.push(...o);
    insideVar.push(...iv);
  }
  return { outside, insideVar };
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
    `audit-component-css-tokens: var 外の生色指定 ${allOutside.length} 件（enforce 対象） | var 内のみ ${allInside.length} 件 | 計 ${total} 件\n`,
  );

  if (allOutside.length > 0) {
    console.error('--- var 外（トークン置換の主対象） ---\n');
    for (const v of allOutside) {
      console.error(`${v.file}:${v.line}  [${v.kind}] ${v.value}`);
      console.error(`  ${v.snippet}\n`);
    }
  }

  if (allInside.length > 0) {
    console.error('--- var(...) 内のみ（フォールバック等・参考） ---\n');
    for (const v of allInside) {
      console.error(`${v.file}:${v.line}  [${v.kind}] ${v.value}`);
      console.error(`  ${v.snippet}\n`);
    }
  }

  if (ENFORCE && allOutside.length > 0) {
    process.exit(1);
  }
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
