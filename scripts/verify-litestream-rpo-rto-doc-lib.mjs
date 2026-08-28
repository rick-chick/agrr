import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const DOC_PATH = 'docs/ops/litestream-rpo-rto-runbook.md';

const REQUIRED_SECTIONS = [
  '## RPO / RTO',
  '## アーキテクチャとリスク',
  '## sync-interval / synchronous の評価',
  '## レプリケーション遅延アラート',
  '## Runbook',
];

const REQUIRED_KEYWORDS = [
  'RPO',
  'RTO',
  '/tmp/production.sqlite3',
  'sync-interval',
  'synchronous',
  'Litestream',
];

const REQUIRED_ALERT_SNIPPETS = [
  'ALERT-LITESTREAM',
  'gcloud',
];

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean; errors: string[] }}
 */
export function verifyLitestreamRpoRtoDoc(repoRoot) {
  const errors = [];
  const docPath = join(repoRoot, DOC_PATH);

  if (!existsSync(docPath)) {
    errors.push(`missing ${DOC_PATH}`);
    return { ok: false, errors };
  }

  const content = readFileSync(docPath, 'utf8');

  for (const section of REQUIRED_SECTIONS) {
    if (!content.includes(section)) {
      errors.push(`${DOC_PATH} must include section: ${section}`);
    }
  }

  for (const keyword of REQUIRED_KEYWORDS) {
    if (!content.includes(keyword)) {
      errors.push(`${DOC_PATH} must mention: ${keyword}`);
    }
  }

  for (const snippet of REQUIRED_ALERT_SNIPPETS) {
    if (!content.includes(snippet)) {
      errors.push(`${DOC_PATH} must include alert snippet: ${snippet}`);
    }
  }

  const runbookHeadingCount = (content.match(/^### Runbook:/gm) ?? []).length;
  if (runbookHeadingCount < 2) {
    errors.push(`${DOC_PATH} must define at least 2 Runbook headings (### Runbook:)`);
  }

  if (!content.includes('config/litestream.yml')) {
    errors.push(`${DOC_PATH} must reference config/litestream.yml`);
  }

  const readmePath = join(repoRoot, 'docs/README.md');
  if (!existsSync(readmePath)) {
    errors.push('missing docs/README.md');
  } else {
    const readme = readFileSync(readmePath, 'utf8');
    if (!readme.includes('litestream-rpo-rto-runbook.md')) {
      errors.push('docs/README.md must index litestream-rpo-rto-runbook.md');
    }
  }

  return { ok: errors.length === 0, errors };
}
