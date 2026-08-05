import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const DOC_PATH = 'docs/ops/core-api-optimization-sli-slo.md';

const REQUIRED_SECTIONS = [
  '## SLI / SLO',
  '## 測定方法',
  '## アラート',
  '## Runbook',
];

const REQUIRED_SLI_KEYWORDS = [
  'API',
  '最適化',
  '可用性',
  '完了率',
];

const REQUIRED_MEASUREMENT_SNIPPETS = [
  'run.googleapis.com',
  'gcloud logging read',
];

const REQUIRED_ALERT_SNIPPETS = [
  '5xx',
  '最適化',
];

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean; errors: string[] }}
 */
export function verifyCoreApiOptimizationSliSloDoc(repoRoot) {
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

  const tableRowMatches = content.match(/^\|[^|]+\|[^|]+\|[^|]+\|/gm) ?? [];
  const dataRows = tableRowMatches.filter(
    (row) => !row.includes('---') && !row.toLowerCase().includes('| sli '),
  );
  if (dataRows.length < 2) {
    errors.push(`${DOC_PATH} must define at least 2 SLI rows in a table`);
  }

  for (const keyword of REQUIRED_SLI_KEYWORDS) {
    if (!content.includes(keyword)) {
      errors.push(`${DOC_PATH} must mention SLI keyword: ${keyword}`);
    }
  }

  for (const snippet of REQUIRED_MEASUREMENT_SNIPPETS) {
    if (!content.includes(snippet)) {
      errors.push(`${DOC_PATH} must include measurement snippet: ${snippet}`);
    }
  }

  for (const snippet of REQUIRED_ALERT_SNIPPETS) {
    if (!content.includes(snippet)) {
      errors.push(`${DOC_PATH} must define user-impact alert for: ${snippet}`);
    }
  }

  if (!content.includes('SLO') || !content.includes('SLI')) {
    errors.push(`${DOC_PATH} must use SLI and SLO terminology`);
  }

  const runbookHeadingCount = (content.match(/^### Runbook:/gm) ?? []).length;
  if (runbookHeadingCount < 2) {
    errors.push(`${DOC_PATH} must link at least 2 alerts to Runbook headings (### Runbook:)`);
  }

  const readmePath = join(repoRoot, 'docs/README.md');
  if (!existsSync(readmePath)) {
    errors.push('missing docs/README.md');
  } else {
    const readme = readFileSync(readmePath, 'utf8');
    if (!readme.includes('core-api-optimization-sli-slo.md')) {
      errors.push('docs/README.md must index core-api-optimization-sli-slo.md');
    }
  }

  return { ok: errors.length === 0, errors };
}
