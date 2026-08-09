import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

export const LAYER_RULES_REL = 'docs/architecture/LAYER-RULES.md';

const FORBIDDEN_STRINGS = [
  'lib/domain',
  'app/controllers',
  'app/adapters',
  'app/models',
  'CompositionRoot',
  'ActiveRecord',
  'Rails.',
];

const ALLOWED_PATH_PREFIXES = [
  'crates/agrr-domain',
  'crates/agrr-server',
  'crates/agrr-adapters-',
  'frontend/src/app/',
  'scripts/run-architecture-guard.sh',
];

const PATH_ROOT_RE = /`((?:crates|frontend|app|lib|scripts)\/[^`]+)`/g;

export const MAX_LAYER_RULES_LINES = 100;

export function checkLayerRulesMd(rootDir) {
  const errors = [];
  const absPath = join(rootDir, LAYER_RULES_REL);
  if (!existsSync(absPath)) {
    return { ok: false, errors: [`${LAYER_RULES_REL}: missing`] };
  }

  const content = readFileSync(absPath, 'utf8');
  const lines = content.split('\n');
  if (lines.length > MAX_LAYER_RULES_LINES) {
    errors.push(`${LAYER_RULES_REL}: ${lines.length} lines, max ${MAX_LAYER_RULES_LINES}`);
  }

  for (const forbidden of FORBIDDEN_STRINGS) {
    if (content.includes(forbidden)) {
      errors.push(`${LAYER_RULES_REL}: forbidden string "${forbidden}"`);
    }
  }

  let match;
  while ((match = PATH_ROOT_RE.exec(content)) !== null) {
    const value = match[1];
    const allowed = ALLOWED_PATH_PREFIXES.some((prefix) => value.startsWith(prefix));
    if (!allowed) {
      errors.push(`${LAYER_RULES_REL}: disallowed path example \`${value}\``);
    }
  }

  const tableRows = content.match(/^\|\s+\*\*R\d+\*\*/gm) ?? [];
  if (tableRows.length < 10) {
    errors.push(`${LAYER_RULES_REL}: expected R0–R10 summary table (>=10 rule rows), got ${tableRows.length}`);
  }

  if (!/run-architecture-guard\.sh/.test(content)) {
    errors.push(`${LAYER_RULES_REL}: must reference scripts/run-architecture-guard.sh`);
  }

  return { ok: errors.length === 0, errors };
}
