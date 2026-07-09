#!/usr/bin/env node
/**
 * 戻るボタン廃止・パンくず統一キャンペーンの機械的完了判定。
 *
 * 使い方（リポジトリルートから）:
 *   node .cursor/skills/ux-campaign-loop/scripts/scan-breadcrumb-campaign.mjs
 *   node .cursor/skills/ux-campaign-loop/scripts/scan-breadcrumb-campaign.mjs --json-out ./tmp/breadcrumb-scan.json
 *
 * 終了コード: 0 = 成功（完了・未完了は JSON の campaignComplete を参照）, 2 = エラー
 */
import { readFile, readdir, writeFile, mkdir } from 'node:fs/promises';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = join(__dirname, '../../../../');
const CAMPAIGN_PATH = join(__dirname, '../campaigns/breadcrumb.json');
const DEFAULT_JSON_OUT = join(
  REPO_ROOT,
  'frontend/e2e/agent-review/breadcrumb-campaign-scan.json',
);

const JSON_OUT_ARG = process.argv.indexOf('--json-out');
const JSON_OUT =
  JSON_OUT_ARG >= 0 ? process.argv[JSON_OUT_ARG + 1] : DEFAULT_JSON_OUT;

const SCAN_ROOTS = [
  'frontend/src/app/components',
];

const EXCLUDE_SUFFIXES = ['.spec.ts', '.spec.tsx'];

/** @type {{ id: string; regex: RegExp; description: string }[]} */
const VIOLATION_PATTERNS = [
  {
    id: 'back_to_list',
    regex: /back_to_list/,
    description: '一覧に戻るリンク（back_to_list）',
  },
  {
    id: 'back_button',
    regex: /back[_-]button/,
    description: '戻るボタン（back_button / back-button）',
  },
  {
    id: 'back_to_parent',
    regex: /back_to_(crop|plan|planting|farm|field)/,
    description: '親画面へ戻るリンク',
  },
  {
    id: 'return_to_plan',
    regex: /return_to_plan/,
    description: '計画へ戻るリンク',
  },
];

const BREADCRUMB_MARKERS = [
  /breadcrumb/,
  /aria-label=["'][^"']*breadcrumb/i,
  /class=["'][^"']*breadcrumb/,
];

/**
 * @param {string} dir
 * @returns {Promise<string[]>}
 */
async function listComponentFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listComponentFiles(full)));
      continue;
    }
    if (!entry.name.endsWith('.ts') && !entry.name.endsWith('.html')) continue;
    if (EXCLUDE_SUFFIXES.some((suffix) => entry.name.endsWith(suffix))) continue;
    files.push(full);
  }
  return files;
}

/**
 * @param {string} relPath
 */
function routeGroupFromPath(relPath) {
  const normalized = relPath.replace(/\\/g, '/');
  const marker = 'frontend/src/app/components/';
  const idx = normalized.indexOf(marker);
  const tail = idx >= 0 ? normalized.slice(idx + marker.length) : normalized;
  const parts = tail.split('/');
  if (parts[0] === 'masters' && parts.length >= 2) {
    return `masters/${parts[1]}`;
  }
  if (parts[0] === 'plans' || parts[0] === 'public-plans') {
    return parts[0];
  }
  return parts.slice(0, 2).join('/') || parts[0] || 'other';
}

/**
 * @param {string} content
 */
function hasBreadcrumbMarker(content) {
  return BREADCRUMB_MARKERS.some((re) => re.test(content));
}

/**
 * @param {string} repoRoot
 * @param {string} filePath
 * @param {string} content
 */
function scanFile(repoRoot, filePath, content) {
  const relPath = relative(repoRoot, filePath).replace(/\\/g, '/');
  const matches = [];

  for (const pattern of VIOLATION_PATTERNS) {
    if (!pattern.regex.test(content)) continue;
    const lines = content.split('\n');
    const lineNumbers = [];
    lines.forEach((line, index) => {
      if (pattern.regex.test(line)) lineNumbers.push(index + 1);
    });
    matches.push({
      patternId: pattern.id,
      description: pattern.description,
      lineNumbers,
    });
  }

  if (matches.length === 0) return null;

  return {
    file: relPath,
    routeGroup: routeGroupFromPath(relPath),
    hasBreadcrumbMarker: hasBreadcrumbMarker(content),
    matches,
  };
}

/**
 * @param {import('../campaigns/breadcrumb.json')} campaign
 * @param {NonNullable<ReturnType<typeof scanFile>>[]} violations
 */
function buildIssueCandidates(campaign, violations) {
  const byGroup = new Map();
  for (const v of violations) {
    const key = v.routeGroup;
    if (!byGroup.has(key)) byGroup.set(key, []);
    byGroup.get(key).push(v);
  }

  return [...byGroup.entries()].map(([routeGroup, files]) => {
    const fileList = files.map((f) => f.file).join(', ');
    return {
      routeGroup,
      files: files.map((f) => f.file),
      suggestedTitle: `${campaign.issueTitlePrefix} ${routeGroup}: ${campaign.issueTitleSuffix}`,
      suggestedBodyLines: [
        `## キャンペーン`,
        campaign.title,
        '',
        '## 対象ファイル',
        ...files.map((f) => `- \`${f.file}\` (${f.matches.map((m) => m.patternId).join(', ')})`),
        '',
        '## 完了条件',
        '- [ ] 戻るボタン／一覧へ戻るリンクを削除',
        '- [ ] `page-header` 直上にパンくず（`nav[aria-label=breadcrumb]` + `ol.breadcrumb`）を追加',
        '- [ ] `ja` / `en` / `in` の `breadcrumb.*` i18n キーを追加・更新',
        '- [ ] 関連 spec を更新（戻るボタン前提のテストを削除またはパンくずに変更）',
        '',
        '## 参照',
        `- レイアウト: \`${campaign.referenceLayout}\``,
        ...campaign.designNotes.map((note) => `- ${note}`),
        '',
        `ラベル: \`${campaign.label}\``,
      ],
      summary: `${routeGroup}: ${fileList}`,
    };
  });
}

export async function scanBreadcrumbCampaign(options = {}) {
  const repoRoot = options.repoRoot ?? REPO_ROOT;
  const campaignPath = options.campaignPath ?? CAMPAIGN_PATH;
  const campaign = JSON.parse(await readFile(campaignPath, 'utf8'));

  const allFiles = [];
  for (const root of SCAN_ROOTS) {
    allFiles.push(...(await listComponentFiles(join(repoRoot, root))));
  }

  const violations = [];
  for (const filePath of allFiles) {
    const content = await readFile(filePath, 'utf8');
    const result = scanFile(repoRoot, filePath, content);
    if (result) violations.push(result);
  }

  const campaignComplete = violations.length === 0;
  const issueCandidates = campaignComplete
    ? []
    : buildIssueCandidates(campaign, violations);

  return {
    campaignId: campaign.id,
    campaignLabel: campaign.label,
    scannedAt: new Date().toISOString(),
    campaignComplete,
    counts: {
      filesScanned: allFiles.length,
      violationFiles: violations.length,
      issueCandidates: issueCandidates.length,
    },
    violations,
    issueCandidates,
  };
}

async function main() {
  try {
    const result = await scanBreadcrumbCampaign();
    await mkdir(dirname(JSON_OUT), { recursive: true });
    await writeFile(JSON_OUT, `${JSON.stringify(result, null, 2)}\n`, 'utf8');

    console.log(
      `breadcrumb-campaign: complete=${result.campaignComplete} violations=${result.counts.violationFiles} candidates=${result.counts.issueCandidates}`,
    );
    console.log(`wrote ${JSON_OUT}`);

    process.exit(0);
  } catch (err) {
    console.error(err instanceof Error ? err.message : String(err));
    process.exit(2);
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main();
}
