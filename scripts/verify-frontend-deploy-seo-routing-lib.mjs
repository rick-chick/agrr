import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const VERIFY_SCRIPT = '.cursor/skills/deploy-frontend/scripts/verify-seo-routing.sh';

const REQUIRED_FRONTEND_DEPLOY_SNIPPETS = [
  'verify-seo-routing',
  VERIFY_SCRIPT,
  "github.event_name == 'push'",
];

const BASE_URL_PATTERNS = ['BASE_URL=https://agrr.net', 'BASE_URL: https://agrr.net'];

const FORBIDDEN_FRONTEND_DEPLOY_SNIPPETS = [
  'continue-on-error: true',
];

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean; errors: string[] }}
 */
export function verifyFrontendDeploySeoRoutingContract(repoRoot) {
  const errors = [];

  const workflowPath = join(repoRoot, '.github/workflows/frontend-deploy.yml');
  if (!existsSync(workflowPath)) {
    errors.push(`missing ${workflowPath}`);
    return { ok: false, errors };
  }

  const workflow = readFileSync(workflowPath, 'utf8');

  for (const snippet of REQUIRED_FRONTEND_DEPLOY_SNIPPETS) {
    if (!workflow.includes(snippet)) {
      errors.push(`frontend-deploy.yml missing required snippet: ${snippet}`);
    }
  }

  if (!BASE_URL_PATTERNS.some((pattern) => workflow.includes(pattern))) {
    errors.push(
      'frontend-deploy.yml must set BASE_URL to https://agrr.net for verify-seo-routing',
    );
  }

  const verifyJobMatch = workflow.match(
    /verify-seo-routing:[\s\S]*?(?=\n  [a-zA-Z0-9_-]+:|$)/,
  );
  if (!verifyJobMatch) {
    errors.push('frontend-deploy.yml must define verify-seo-routing job');
  } else {
    const verifyJob = verifyJobMatch[0];
    if (!verifyJob.includes('needs: build-and-deploy')) {
      errors.push('verify-seo-routing job must need build-and-deploy');
    }
    if (!verifyJob.includes('timeout-minutes:')) {
      errors.push('verify-seo-routing job must set timeout-minutes');
    }
    for (const snippet of FORBIDDEN_FRONTEND_DEPLOY_SNIPPETS) {
      if (verifyJob.includes(snippet)) {
        errors.push(`verify-seo-routing job must not include: ${snippet}`);
      }
    }
  }

  const researchWorkflowPath = join(repoRoot, '.github/workflows/research-deploy.yml');
  if (!existsSync(researchWorkflowPath)) {
    errors.push(`missing ${researchWorkflowPath}`);
  } else {
    const researchWorkflow = readFileSync(researchWorkflowPath, 'utf8');
    if (!researchWorkflow.includes(VERIFY_SCRIPT)) {
      errors.push('research-deploy.yml must still run verify-seo-routing.sh');
    }
  }

  const runbookPath = join(repoRoot, 'docs/seo/gsc-crux-operations-runbook.md');
  if (!existsSync(runbookPath)) {
    errors.push(`missing ${runbookPath}`);
  } else {
    const runbook = readFileSync(runbookPath, 'utf8');
    if (!runbook.includes('frontend-deploy')) {
      errors.push('gsc-crux-operations-runbook.md must mention frontend-deploy CI integration');
    }
    if (runbook.includes('HTTP 検証 | **手動**（デプロイ後）')) {
      errors.push('gsc-crux-operations-runbook.md §3 must not list HTTP verification as manual-only');
    }
  }

  return { ok: errors.length === 0, errors };
}
