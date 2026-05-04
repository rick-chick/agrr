#!/usr/bin/env node
/**
 * src/app/routes/*.routes.ts から path / auth 要否を抽出し、E2E 用 URL 一覧を生成する。
 * 単一の情報源にしてエージェントが「ページを教えて」と聞かないようにする。
 */
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND = join(__dirname, '..');
const ROUTES_DIR = join(FRONTEND, 'src/app/routes');
const OUT = join(FRONTEND, 'e2e', 'route-manifest.json');
const ROUTE_TO_PNG = join(FRONTEND, 'e2e', 'agent-review', 'route-to-png.md');

function pngBasenameForPattern(pattern) {
  if (pattern === '') return 'home';
  if (pattern === '**') return 'not-found';
  return pattern.replace(/[^\w.-]+/g, '_');
}

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
      'path の :param は URL では 1 に置換。`**` は意図的な 404 用パス。Agent 用 PNG は Playwright で `GET /api/v1/auth/me` をモックして storage state なしでも全ルートをキャプチャする。requiresAuth はルート定義上のフラグ。',
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
    '- `pattern` が空文字 → `home.png`',
    '- `pattern` が `**` → `not-found.png`',
    '- それ以外 → `pattern` のうち `[a-zA-Z0-9_.-]` 以外を `_` に置換し、`.png` を付与',
    '',
    '## 全ルート一覧',
    '',
    '| # | pattern | url (E2E goto) | requiresAuth | out/*.png |',
    '|---|---------|----------------|--------------|-----------|',
  ];
  deduped.forEach((r, i) => {
    const base = pngBasenameForPattern(r.pattern);
    const esc = (s) => String(s).replace(/\|/g, '\\|');
    const patDisp = r.pattern === '' ? '(home)' : r.pattern;
    lines.push(
      `| ${i + 1} | \`${esc(patDisp)}\` | \`${esc(r.url)}\` | ${r.requiresAuth ? 'yes' : 'no'} | \`${esc(base)}.png\` |`,
    );
  });
  lines.push('');
  lines.push('## キャプチャ前提');
  lines.push('');
  lines.push(
    '- `e2e:capture-for-agent` は **storage state 不要**。Playwright が `GET /api/v1/auth/me` を成功レスポンスに置き換え、authGuard 通過後に各 `url` へ遷移して `out/*.png` を書き出す。',
  );
  lines.push(
    '- 一覧・詳細はバックエンド未取得時もレイアウトレビュー用に撮影される。実データ・本番同等 UI が必要なら別途 API 起動や `e2e/.auth` を用いる。',
  );
  lines.push('');
  await writeFile(ROUTE_TO_PNG, lines.join('\n'), 'utf8');
  console.log(`wrote ${ROUTE_TO_PNG}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
