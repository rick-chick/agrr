import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

import {
  REQUIRED_CI_CONTEXTS,
  REQUIRED_WHEN_PRESENT_CI_CONTEXTS,
  RULESET_CI_CONTEXTS,
} from './pr-agent-prep-lib.mjs';

/**
 * @param {string[]} actualContexts
 * @returns {{ ok: boolean; missing: string[] }}
 */
export function verifyRulesetContexts(actualContexts) {
  const actual = new Set(actualContexts);
  const missing = RULESET_CI_CONTEXTS.filter((context) => !actual.has(context));
  return { ok: missing.length === 0, missing };
}

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyRulesetCiContract(repoRoot) {
  const errors = [];
  const lintWorkflowPath = join(repoRoot, '.github/workflows/lint.yml');
  const e2eSmokeWorkflowPath = join(repoRoot, '.github/workflows/frontend-e2e-smoke.yml');

  let lintWorkflowText = '';
  try {
    lintWorkflowText = await readFile(lintWorkflowPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${lintWorkflowPath}`);
  }

  if (!lintWorkflowText.includes('run-architecture-guard:')) {
    errors.push('lint.yml must define run-architecture-guard job');
  }

  if (!RULESET_CI_CONTEXTS.includes('lint / run-architecture-guard')) {
    errors.push('RULESET_CI_CONTEXTS must include lint / run-architecture-guard');
  }

  if (!REQUIRED_CI_CONTEXTS.includes('frontend-e2e-smoke')) {
    errors.push('REQUIRED_CI_CONTEXTS must include frontend-e2e-smoke');
  }

  if (!REQUIRED_WHEN_PRESENT_CI_CONTEXTS.includes('frontend-e2e-smoke')) {
    errors.push('frontend-e2e-smoke must be required-when-present (path-filtered workflow)');
  }

  try {
    const e2eSmokeWorkflowText = await readFile(e2eSmokeWorkflowPath, 'utf8');
    if (!e2eSmokeWorkflowText.includes('frontend-e2e-smoke:')) {
      errors.push('frontend-e2e-smoke.yml must define frontend-e2e-smoke job');
    }
  } catch {
    errors.push(`missing workflow: ${e2eSmokeWorkflowPath}`);
  }

  return { ok: errors.length === 0, errors };
}
