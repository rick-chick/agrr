#!/usr/bin/env node
/**
 * visual-review-results.md と audit:css-tokens の出力から UX/UI 改善 Issue 草案を生成する。
 *
 * 使い方（リポジトリルートから）:
 *   node .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs
 *   node .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs --css-audit-log ./tmp/css-audit.log
 *   node .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs --skip-gh
 *
 * 出力:
 *   frontend/e2e/agent-review/ux-findings-draft.json
 *   frontend/e2e/agent-review/ux-issue-drafts.md
 */
import { execFile } from 'node:child_process';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { promisify } from 'node:util';

import {
  attachIssueCandidates,
  buildCssFindings,
  buildVisualFindings,
  isLikelyDuplicateFinding,
  parseCssAuditLog,
  parseDetailedFindings,
  parseVisualReviewTable,
} from './collect-ux-findings-parsers.mjs';

const execFileAsync = promisify(execFile);

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = join(__dirname, '../../../../');
const GITHUB_REPO = 'rick-chick/agrr';
const VISUAL_REVIEW_PATH = join(
  REPO_ROOT,
  'frontend/e2e/agent-review/visual-review-results.md',
);
const OUT_DIR = join(REPO_ROOT, 'frontend/e2e/agent-review');
const JSON_OUT = join(OUT_DIR, 'ux-findings-draft.json');
const MD_OUT = join(OUT_DIR, 'ux-issue-drafts.md');

const CSS_LOG_ARG = process.argv.indexOf('--css-audit-log');
const CSS_LOG_PATH =
  CSS_LOG_ARG >= 0 ? process.argv[CSS_LOG_ARG + 1] : null;
const SKIP_GH = process.argv.includes('--skip-gh');

async function runCssAudit() {
  try {
    const { stdout, stderr } = await execFileAsync(
      'npm',
      ['run', 'audit:css-tokens'],
      { cwd: join(REPO_ROOT, 'frontend'), maxBuffer: 10 * 1024 * 1024 },
    );
    return `${stderr || ''}${stdout || ''}`;
  } catch (err) {
    return `${err.stderr || ''}${err.stdout || ''}${String(err)}`;
  }
}

async function fetchGithubIssues() {
  if (SKIP_GH) return { issues: [], status: 'skipped' };
  try {
    const { stdout } = await execFileAsync('gh', [
      'issue',
      'list',
      '--repo',
      GITHUB_REPO,
      '--state',
      'all',
      '--limit',
      '200',
      '--json',
      'number,title,state',
    ]);
    return { issues: JSON.parse(stdout), status: 'ok' };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(
      `collect-ux-findings: gh issue list failed (${message}); duplicate detection disabled`,
    );
    return { issues: [], status: 'failed' };
  }
}

/**
 * @param {Array<Record<string, unknown>>} findings
 */
export function renderMarkdownDraft(findings) {
  const lines = [
    '# UX/UI Issue 草案（自動生成）',
    '',
    `生成: ${new Date().toISOString()}`,
    '',
    '**次のステップ**: `ux-issue-creator` スキルに従い、`existingIssueCandidates` を確認のうえ `gh issue create` する。',
    '',
    '## 一覧',
    '',
    '| id | 優先 | 区分 | pattern | 既存候補 | 提案タイトル |',
    '|----|------|------|---------|----------|--------------|',
  ];

  for (const f of findings) {
    const title = String(f.suggestedTitle).replace(/\|/g, '\\|');
    const candidates = (f.existingIssueCandidates || [])
      .map((c) => `#${c.number}`)
      .join(', ') || '—';
    lines.push(
      `| ${f.id} | ${f.priority} | ${f.category} | \`${f.pattern}\` | ${candidates} | ${title} |`,
    );
  }

  lines.push('', '## 本文草案', '');

  for (const f of findings) {
    lines.push(`### ${f.id}`, '');
    if (f.existingIssueCandidates?.length) {
      lines.push('**既存 issue 候補**:');
      for (const c of f.existingIssueCandidates) {
        lines.push(`- #${c.number} (${c.state}, score ${c.score}): ${c.title}`);
      }
      lines.push('');
    }
    lines.push(`**提案タイトル**: ${f.suggestedTitle}`, '');
    lines.push('```markdown');

    if (f.source === 'visual-review') {
      const rowRef = f.mergeGroup
        ? `visual-review #${(f.visualReviewRows || []).join(', #')}`
        : `visual-review #${f.visualReviewRow}`;
      const layoutNote = f.mergeGroup
        ? `複数行統合（patterns: ${(f.patterns || [f.pattern]).join(', ')}）`
        : `layout=${f.layoutResult || '—'}, i18n=${f.i18nResult || '—'}`;
      lines.push('## 背景', '');
      lines.push(`${f.summary}（${rowRef}, ${layoutNote}）。`, '');
      lines.push('## 再現手順', '');
      if (f.pattern) lines.push(`- ルート: ${f.pattern}`);
      if (f.png?.length) lines.push(`- PNG: ${f.png.join(', ')}`);
      lines.push('- 上記画面で指摘どおりの表示・操作を確認（起票前に実施済み）');
      lines.push('', '## 完了条件', '');
      lines.push('- [ ] 3 言語キャプチャで指摘が解消');
      lines.push('- [ ] 関連テスト GREEN', '', '## 依存', '', 'なし', '', '## 参照', '');
      lines.push(`- ${rowRef}`);
      lines.push(`- PNG: ${(f.png || []).join(', ')}`);
    } else {
      lines.push('## 背景', '');
      lines.push(`${f.summary}。`, '', '## 再現手順', '');
      lines.push('- `cd frontend && npm run audit:css-tokens` で var 外違反を確認（起票前に実施済み）');
      lines.push('', '## 完了条件', '');
      lines.push('- [ ] audit:css-tokens:enforce exit 0');
      lines.push('- [ ] 表示のビジュアル回帰なし', '', '## 依存', '', 'なし', '', '## 参照', '');
      lines.push('- `npm run audit:css-tokens`');
      for (const v of f.violations || []) {
        lines.push(`- \`${v.file}:${v.line}\` ${v.value}`);
      }
    }

    lines.push('```', '');
  }

  return lines.join('\n');
}

async function main() {
  const visualMarkdown = await readFile(VISUAL_REVIEW_PATH, 'utf8');
  const tableRows = parseVisualReviewTable(visualMarkdown);
  const detailedItems = parseDetailedFindings(visualMarkdown);
  const visualFindings = buildVisualFindings(tableRows, detailedItems);

  let cssLog = '';
  if (CSS_LOG_PATH) {
    cssLog = await readFile(CSS_LOG_PATH, 'utf8');
  } else {
    cssLog = await runCssAudit();
  }
  const cssViolations = parseCssAuditLog(cssLog);
  const cssFindings = buildCssFindings(cssViolations);

  const rawFindings = [...visualFindings, ...cssFindings];
  const { issues, status: githubLookupStatus } = await fetchGithubIssues();
  const findings = attachIssueCandidates(rawFindings, issues);

  const mergeGroups = findings.filter((f) => f.mergeGroup === true);
  const skippable = findings.filter(isLikelyDuplicateFinding);

  const payload = {
    generatedAt: new Date().toISOString(),
    sources: {
      visualReview: 'frontend/e2e/agent-review/visual-review-results.md',
      cssAudit: CSS_LOG_PATH || 'npm run audit:css-tokens (frontend/)',
      githubIssues: SKIP_GH ? 'skipped' : `gh issue list --repo ${GITHUB_REPO}`,
      githubLookupStatus,
    },
    counts: {
      visual: visualFindings.length,
      css: cssFindings.length,
      mergeGroups: mergeGroups.length,
      total: findings.length,
      likelyDuplicateOpen: skippable.length,
    },
    mergeGroups: mergeGroups.map((g) => ({
      id: g.id,
      rows: g.visualReviewRows,
      patterns: g.patterns,
      suggestedTitle: g.suggestedTitle,
      existingIssueCandidates: g.existingIssueCandidates,
    })),
    findings,
  };

  await mkdir(OUT_DIR, { recursive: true });
  await writeFile(JSON_OUT, `${JSON.stringify(payload, null, 2)}\n`);
  await writeFile(MD_OUT, `${renderMarkdownDraft(findings)}\n`);

  console.log(`collect-ux-findings: ${findings.length} 件`);
  console.log(`  visual: ${visualFindings.length}, css: ${cssFindings.length}, merge: ${mergeGroups.length}`);
  console.log(`  likely duplicate (open): ${skippable.length}`);
  console.log(`  github lookup: ${githubLookupStatus}`);
  if (githubLookupStatus === 'failed') {
    console.warn('collect-ux-findings: githubLookupStatus=failed — 起票前に gh 認証・重複確認を再実行すること');
  }
  console.log(`  → ${JSON_OUT}`);
  console.log(`  → ${MD_OUT}`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
