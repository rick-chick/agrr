import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

export const ALLOWED_ALWAYS_APPLY = [
  'git-operational-constraints.mdc',
  'tdd-on-edit.mdc',
  'docker-dev-agrr-server-rebuild.mdc',
  'test-common-entry.mdc',
];

export const DEMOTED_ALWAYS_APPLY = [
  'agent-conventions.mdc',
  'rails-clean-architecture.mdc',
  'evidence-before-design-and-implementation.mdc',
  'no-convenience-tech-debt.mdc',
  'automation-philosophy-priority.mdc',
  'user-request-project-alignment.mdc',
  'project-necessary-code-only.mdc',
  'gcp-available.mdc',
  'naming-ules.mdc',
];

const MAX_ALWAYS_APPLY_LINES = 80;
const ALWAYS_APPLY_RE = /^\s*alwaysApply:\s*true\s*$/m;
const ALWAYS_APPLY_FALSE_RE = /^\s*alwaysApply:\s*false\s*$/m;

function readRuleFile(root, name) {
  return readFileSync(join(root, '.cursor', 'rules', name), 'utf8');
}

function lineCount(text) {
  return text.split('\n').length;
}

function parseClaudeAlwaysApplyRefs(claudeText) {
  const section = claudeText.split('## Always-apply rules')[1]?.split('## ')[0] ?? '';
  return [...section.matchAll(/@\.cursor\/rules\/([^\s]+)/g)].map((m) => m[1]);
}

export function verifyAlwaysApplyRules(root) {
  const errors = [];
  const rulesDir = join(root, '.cursor', 'rules');
  const ruleFiles = readdirSync(rulesDir).filter((f) => f.endsWith('.mdc'));

  const alwaysApplyTrue = ruleFiles.filter((name) => {
    const text = readRuleFile(root, name);
    return ALWAYS_APPLY_RE.test(text);
  });

  if (alwaysApplyTrue.length !== ALLOWED_ALWAYS_APPLY.length) {
    errors.push(
      `expected ${ALLOWED_ALWAYS_APPLY.length} alwaysApply:true rules, found ${alwaysApplyTrue.length}: ${alwaysApplyTrue.join(', ')}`,
    );
  }

  for (const name of ALLOWED_ALWAYS_APPLY) {
    if (!alwaysApplyTrue.includes(name)) {
      errors.push(`missing alwaysApply:true: ${name}`);
    }
  }

  for (const name of alwaysApplyTrue) {
    if (!ALLOWED_ALWAYS_APPLY.includes(name)) {
      errors.push(`unexpected alwaysApply:true: ${name}`);
    }
  }

  let totalLines = 0;
  for (const name of ALLOWED_ALWAYS_APPLY) {
    const text = readRuleFile(root, name);
    totalLines += lineCount(text);
  }

  if (totalLines > MAX_ALWAYS_APPLY_LINES) {
    errors.push(
      `alwaysApply rules total ${totalLines} lines exceeds max ${MAX_ALWAYS_APPLY_LINES}`,
    );
  }

  for (const name of DEMOTED_ALWAYS_APPLY) {
    const text = readRuleFile(root, name);
    if (!ALWAYS_APPLY_FALSE_RE.test(text)) {
      errors.push(`${name} must have alwaysApply: false`);
    }
  }

  const claudeText = readFileSync(join(root, 'CLAUDE.md'), 'utf8');
  const refs = parseClaudeAlwaysApplyRefs(claudeText);
  const expectedRefs = [...ALLOWED_ALWAYS_APPLY].sort();
  const actualRefs = [...refs].sort();

  if (actualRefs.join(',') !== expectedRefs.join(',')) {
    errors.push(
      `CLAUDE.md Always-apply refs mismatch: expected [${expectedRefs.join(', ')}], got [${actualRefs.join(', ')}]`,
    );
  }

  return { ok: errors.length === 0, errors, totalLines };
}
