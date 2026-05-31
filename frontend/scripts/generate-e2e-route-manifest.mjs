#!/usr/bin/env node
/**
 * src/app/routes/*.routes.ts から path / auth 要否を抽出し、E2E 用 URL 一覧を生成する。
 * 単一の情報源にしてエージェントが「ページを教えて」と聞かないようにする。
 */
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CAPTURE_LOCALES, agentPngFilename } from '../e2e/capture-locales.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND = join(__dirname, '..');
const ROUTES_DIR = join(FRONTEND, 'src/app/routes');
const OUT = join(FRONTEND, 'e2e', 'route-manifest.json');
const ROUTE_TO_PNG = join(FRONTEND, 'e2e', 'agent-review', 'route-to-png.md');

/** SPA 内リダイレクトのみ。ログイン UI は `/login` で E2E する */
const E2E_EXCLUDE_MANIFEST_PATTERNS = new Set(['auth/login']);

function patternToUrl(pattern) {
  if (pattern === '') return '/';
  if (pattern === '**') return '/__e2e-route-manifest-not-found__';
  if (pattern === 'public-plans/optimizing') return '/public-plans/optimizing?planId=1';
  if (pattern === 'public-plans/results') return '/public-plans/results?planId=1';
  if (pattern === 'entry-schedule/crop/:cropId') return '/entry-schedule/crop/1?farmId=1';
  let p = pattern.replace(/:[a-zA-Z_][a-zA-Z0-9_]*/g, '1');
  if (!p.startsWith('/')) p = `/${p}`;
  return p;
}

async function parseRoutesFile(filePath) {
  const text = await readFile(filePath, 'utf8');
  const clean = text
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\/\/[^\n]*/g, '');
  const pathRegex = /\bpath:\s*['"]([^'"]*)['"]/g;
  const positions = [];
  let m;
  while ((m = pathRegex.exec(clean)) !== null) {
    positions.push({ path: m[1], index: m.index });
  }
  const routes = [];
  for (let i = 0; i < positions.length; i++) {
    const start = positions[i].index;
    const end = i + 1 < positions.length ? positions[i + 1].index : clean.length;
    const segment = clean.slice(start, end);
    const requiresAuth = /\bauthGuard\b/.test(segment);
    const pattern = positions[i].path;
    routes.push({
      pattern,
      url: patternToUrl(pattern),
      requiresAuth,
      source: basename(filePath),
    });
  }
  return routes;
}

async function main() {
  const files = (await readdir(ROUTES_DIR)).filter((f) => f.endsWith('.routes.ts')).sort();
  const all = [];
  for (const f of files) {
    all.push(...(await parseRoutesFile(join(ROUTES_DIR, f))));
  }

  const seen = new Set();
  const deduped = [];
  for (const r of all) {
    if (E2E_EXCLUDE_MANIFEST_PATTERNS.has(r.pattern)) continue;
    const k = `${r.pattern}\0${r.requiresAuth}`;
    if (seen.has(k)) continue;
    seen.add(k);
    deduped.push(r);
  }

  deduped.sort((a, b) => {
    if (a.requiresAuth !== b.requiresAuth) return a.requiresAuth ? 1 : -1;
    return a.url.localeCompare(b.url);
  });

  const payload = {
    generatedAt: new Date().toISOString(),
    note:
      'path の :param は URL では 1 に置換。`**` は意図的な 404 用パス。Agent 用 PNG は `npm run e2e:capture-for-agent`（Rails development + AuthTest モックログインで付与したセッション、`e2e/.auth/dev-session.json`）で全ルートを ja/en/in の3言語キャプチャする。requiresAuth はルート定義上のフラグ。',
    routes: deduped,
  };

  await writeFile(OUT, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  console.log(`wrote ${OUT} (${deduped.length} routes)`);

  const lines = [
    '# route-manifest → agent-review/out PNG ファイル名',
    '',
    '**この表は `npm run e2e:manifest` で自動生成する。** Agent はユーザーに URL やページ指定を求めず、この表と `e2e/route-manifest.json` を正とする。',
    '',
    '## ファイル名規則（`e2e/visual/route-manifest-visual.spec.ts` と同一）',
    '',
    '- ベース名: `pattern` が空文字 → `home` / `**` → `not-found` / それ以外は `[a-zA-Z0-9_.-]` 以外を `_` に置換',
    `- 出力: \`{ベース名}.{locale}.png\`（locale: ${CAPTURE_LOCALES.join(', ')}。in はヒンディー語・インド向け）`,
    '',
    '## 全ルート一覧',
    '',
    '| # | pattern | url (E2E goto) | requiresAuth | ja | en | in |',
    '|---|---------|----------------|--------------|----|----|-----|',
  ];
  deduped.forEach((r, i) => {
    const esc = (s) => String(s).replace(/\|/g, '\\|');
    const patDisp = r.pattern === '' ? '(home)' : r.pattern;
    const pngCols = CAPTURE_LOCALES.map(
      (locale) => `\`${esc(agentPngFilename(r.pattern, locale))}\``,
    ).join(' | ');
    lines.push(
      `| ${i + 1} | \`${esc(patDisp)}\` | \`${esc(r.url)}\` | ${r.requiresAuth ? 'yes' : 'no'} | ${pngCols} |`,
    );
  });
  lines.push('');
  lines.push('## キャプチャ前提');
  lines.push('');
  lines.push(
    '- `e2e:capture-for-agent` は **`E2E_CAPTURE_DEV_SESSION=1`** で Rails（127.0.0.1:3000）と ng を起動し、globalSetup が **`e2e/.auth/dev-session.json`** を書き出したうえで各 `url` へ **ja / en / in** の順で遷移し `out/{ベース}.{locale}.png` を書き出す（`/api/v1/auth/me` はモックしない）。',
  );
  lines.push(
    '- `e2e/resolve-capture-urls.ts` が一覧 API から実在 id を取りマニフェストの placeholder を差し替える。DB が空や API 不全のときは画面が薄い・エラーになり得る。',
  );
  lines.push('');
  await writeFile(ROUTE_TO_PNG, lines.join('\n'), 'utf8');
  console.log(`wrote ${ROUTE_TO_PNG}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
