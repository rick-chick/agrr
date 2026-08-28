#!/usr/bin/env node
/**
 * tmp/critical-bug-audit/verified-findings.json を検証し、起票草案を生成する。
 *
 * 使い方（リポジトリルートから）:
 *   node .cursor/skills/critical-bug-audit-pipeline/scripts/collect-critical-findings.mjs
 *   node .cursor/skills/critical-bug-audit-pipeline/scripts/collect-critical-findings.mjs --skip-gh
 *
 * 出力:
 *   tmp/critical-bug-audit/issue-drafts.md
 *   tmp/critical-bug-audit/bodies/<finding-id>.md
 */
import { execFile } from 'node:child_process';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = join(__dirname, '../../../../');
const AUDIT_DIR = join(REPO_ROOT, 'tmp/critical-bug-audit');
const INPUT_JSON = join(AUDIT_DIR, 'verified-findings.json');
const MD_OUT = join(AUDIT_DIR, 'issue-drafts.md');
const BODIES_DIR = join(AUDIT_DIR, 'bodies');
const GITHUB_REPO = 'rick-chick/agrr';
const SKIP_GH = process.argv.includes('--skip-gh');

/**
 * @param {string} title
 * @returns {string[]}
 */
export function extractKeywords(title) {
  return title
    .toLowerCase()
    .replace(/\[p[0-2]\]/gi, '')
    .replace(/\[bug\]/gi, '')
    .replace(/[^\p{L}\p{N}\s/_-]/gu, ' ')
    .split(/\s+/)
    .filter((w) => w.length >= 4);
}

/**
 * @param {Record<string, unknown>} finding
 * @param {{ number: number, title: string, state: string }[]} issues
 */
export function scoreDuplicate(finding, issues) {
  const keywords = extractKeywords(
    String(finding.suggested_issue_title || finding.title || ''),
  );
  const paths = (finding.evidence || []).map((e) => String(e.path || ''));

  return issues
    .map((issue) => {
      let score = 0;
      const t = issue.title.toLowerCase();
      const matched = keywords.filter((k) => t.includes(k));
      if (matched.length >= 2) score += 3;
      else if (matched.length === 1) score += 2;
      for (const p of paths) {
        const base = p.split('/').pop() || '';
        if (base && issue.title.toLowerCase().includes(base.replace(/\.[^.]+$/, ''))) {
          score += 2;
          break;
        }
      }
      if (issue.state === 'OPEN') score += 2;
      return { ...issue, score, matchedKeywords: matched };
    })
    .filter((c) => c.score >= 3)
    .sort((a, b) => b.score - a.score)
    .slice(0, 5);
}

/**
 * @param {unknown} finding
 * @returns {string[]}
 */
export function validateConfirmedFinding(finding) {
  const errors = [];
  const f = /** @type {Record<string, unknown>} */ (finding);
  if (f.status !== 'CONFIRMED') return errors;
  if (!f.repro_steps || !Array.isArray(f.repro_steps) || f.repro_steps.length === 0) {
    errors.push(`${f.id}: CONFIRMED requires repro_steps`);
  }
  if (!f.evidence || !Array.isArray(f.evidence) || f.evidence.length === 0) {
    errors.push(`${f.id}: CONFIRMED requires evidence`);
  }
  if (
    !f.acceptance_criteria ||
    !Array.isArray(f.acceptance_criteria) ||
    f.acceptance_criteria.length === 0
  ) {
    errors.push(`${f.id}: CONFIRMED requires acceptance_criteria`);
  }
  if (!f.suggested_issue_title) {
    errors.push(`${f.id}: CONFIRMED requires suggested_issue_title`);
  }
  return errors;
}

/**
 * @param {Record<string, unknown>} finding
 */
export function renderIssueBody(finding) {
  const repro = (finding.repro_steps || [])
    .map((s, i) => `${i + 1}. ${s}`)
    .join('\n');
  const evidence = (finding.evidence || [])
    .map((e) => `- \`${e.path}\` ${e.lines || ''}${e.note ? ` — ${e.note}` : ''}`)
    .join('\n');
  const acceptance = (finding.acceptance_criteria || [])
    .map((c) => `- [ ] ${c}`)
    .join('\n');
  const related = (finding.existingIssueCandidates || [])
    .filter((c) => c.score >= 5 && c.state === 'OPEN')
    .map((c) => `#${c.number}`)
    .join(', ');

  return `## 背景 / 再現手順

${repro}

## 期待する動作

ユーザーが主要価値（保存・同期・認証・コア操作）を安全に完了できる。

## 実際の動作

${finding.user_impact || finding.title}

## 根拠（コード）

${evidence}

## 完了条件

${acceptance}
- [ ] test-common GREEN

## 依存

- なし

## 参照

- 監査 run: \`${finding.auditRunId || 'unknown'}\`
- カテゴリ: \`${finding.category}\`
${related ? `- 重複候補（要確認）: ${related}` : ''}
`;
}

/**
 * @param {Array<Record<string, unknown>>} findings
 */
export function renderMarkdownDraft(findings, meta) {
  const lines = [
    '# ユーザ致命的バグ Issue 草案（自動生成）',
    '',
    `生成: ${new Date().toISOString()}`,
    `auditRunId: ${meta.auditRunId || '—'}`,
    `githubLookupStatus: ${meta.githubLookupStatus}`,
    '',
    '**次のステップ**: `critical-bug-audit-pipeline` フェーズ 4 ドライラン → `gh issue create`',
    '',
    '## 起票予定（CONFIRMED）',
    '',
    '| id | 優先 | カテゴリ | 重複候補 | 提案タイトル | 起票 |',
    '|----|------|----------|----------|--------------|------|',
  ];

  for (const f of findings.filter((x) => x.status === 'CONFIRMED')) {
    const dup = (f.existingIssueCandidates || [])
      .filter((c) => c.score >= 5 && c.state === 'OPEN')
      .map((c) => `#${c.number}(${c.score})`)
      .join(', ') || '—';
    const skip = (f.existingIssueCandidates || []).some(
      (c) => c.score >= 5 && c.state === 'OPEN',
    );
    lines.push(
      `| ${f.id} | ${f.severity} | ${f.category} | ${dup} | ${f.suggested_issue_title} | ${skip ? 'SKIP' : 'CREATE'} |`,
    );
  }

  lines.push('', '## スキップ', '');
  for (const f of findings.filter((x) => x.status !== 'CONFIRMED')) {
    lines.push(`- **${f.id}** (${xStatus(f)}): ${f.status_reason || f.title}`);
  }
  const confirmed = findings.filter((x) => x.status === 'CONFIRMED');
  for (const f of confirmed) {
    if ((f.existingIssueCandidates || []).some((c) => c.score >= 5 && c.state === 'OPEN')) {
      lines.push(`- **${f.id}**: 重複 OPEN issue あり`);
    }
  }

  return lines.join('\n');
}

/** @param {Record<string, unknown>} f */
function xStatus(f) {
  return String(f.status);
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
    console.error(`collect-critical-findings: gh failed (${message})`);
    return { issues: [], status: 'failed' };
  }
}

async function main() {
  let raw;
  try {
    raw = await readFile(INPUT_JSON, 'utf8');
  } catch {
    console.error(`collect-critical-findings: missing ${INPUT_JSON}`);
    process.exit(1);
  }

  /** @type {Record<string, unknown>} */
  const data = JSON.parse(raw);
  const findings = /** @type {Array<Record<string, unknown>>} */ (
    data.findings || []
  );

  const validationErrors = findings.flatMap(validateConfirmedFinding);
  if (validationErrors.length > 0) {
    console.error('collect-critical-findings: validation failed:');
    for (const e of validationErrors) console.error(`  - ${e}`);
    process.exit(1);
  }

  const { issues, status } = await fetchGithubIssues();
  if (status === 'failed') {
    data.sources = { ...(data.sources || {}), githubLookupStatus: 'failed' };
    await writeFile(INPUT_JSON, `${JSON.stringify(data, null, 2)}\n`);
    console.error('collect-critical-findings: githubLookupStatus=failed → 起票禁止');
    process.exit(1);
  }

  data.sources = { ...(data.sources || {}), githubLookupStatus: status };

  let likelyDuplicateOpen = 0;
  for (const f of findings) {
    f.existingIssueCandidates = scoreDuplicate(f, issues);
    if (
      f.status === 'CONFIRMED' &&
      f.existingIssueCandidates.some((c) => c.score >= 5 && c.state === 'OPEN')
    ) {
      likelyDuplicateOpen += 1;
    }
  }

  data.counts = {
    total: findings.length,
    confirmed: findings.filter((f) => f.status === 'CONFIRMED').length,
    rejected: findings.filter((f) => f.status === 'REJECTED').length,
    downgraded: findings.filter((f) => f.status === 'DOWNGRADED').length,
    likelyDuplicateOpen,
  };

  await mkdir(BODIES_DIR, { recursive: true });
  for (const f of findings.filter((x) => x.status === 'CONFIRMED')) {
    f.auditRunId = data.auditRunId;
    const bodyPath = join(BODIES_DIR, `${f.id}.md`);
    await writeFile(bodyPath, renderIssueBody(f));
  }

  await writeFile(INPUT_JSON, `${JSON.stringify(data, null, 2)}\n`);
  await mkdir(AUDIT_DIR, { recursive: true });
  await writeFile(
    MD_OUT,
    renderMarkdownDraft(findings, {
      auditRunId: data.auditRunId,
      githubLookupStatus: status,
    }),
  );

  console.log(`collect-critical-findings: wrote ${MD_OUT}`);
  console.log(
    `counts: confirmed=${data.counts.confirmed} rejected=${data.counts.rejected} downgraded=${data.counts.downgraded} likelyDuplicateOpen=${likelyDuplicateOpen}`,
  );
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMain) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
