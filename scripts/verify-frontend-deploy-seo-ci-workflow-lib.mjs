import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

const FRONTEND_DEPLOY_WORKFLOW = '.github/workflows/frontend-deploy.yml';
const RESEARCH_DEPLOY_WORKFLOW = '.github/workflows/research-deploy.yml';
const RUNBOOK_PATH = 'docs/seo/gsc-crux-operations-runbook.md';

/**
 * @param {string} repoRoot
 * @returns {Promise<{ ok: boolean; errors: string[] }>}
 */
export async function verifyFrontendDeploySeoCiWorkflow(repoRoot) {
  const errors = [];

  const frontendDeployPath = join(repoRoot, FRONTEND_DEPLOY_WORKFLOW);
  let frontendDeployText;
  try {
    frontendDeployText = await readFile(frontendDeployPath, 'utf8');
  } catch {
    errors.push(`missing workflow: ${frontendDeployPath}`);
    frontendDeployText = '';
  }

  const requiredFrontendSnippets = [
    'verify-seo-routing.sh',
    'BASE_URL: https://agrr.net',
    "if: github.event_name == 'push'",
    'Verify SEO routing',
  ];

  for (const snippet of requiredFrontendSnippets) {
    if (!frontendDeployText.includes(snippet)) {
      errors.push(`frontend-deploy.yml missing required snippet: ${snippet}`);
    }
  }

  if (frontendDeployText.includes('continue-on-error: true')) {
    const seoStepBlock = extractStepBlock(frontendDeployText, 'Verify SEO routing');
    if (seoStepBlock.includes('continue-on-error: true')) {
      errors.push('frontend-deploy.yml SEO verify step must not use continue-on-error');
    }
  }

  const deployIndex = frontendDeployText.indexOf('Run deploy script');
  const verifyIndex = frontendDeployText.indexOf('Verify SEO routing');
  if (deployIndex === -1) {
    errors.push('frontend-deploy.yml missing deploy step anchor: Run deploy script');
  } else if (verifyIndex === -1) {
    errors.push('frontend-deploy.yml missing SEO verify step anchor: Verify SEO routing');
  } else if (verifyIndex < deployIndex) {
    errors.push('frontend-deploy.yml SEO verify must run after deploy script');
  }

  const researchDeployPath = join(repoRoot, RESEARCH_DEPLOY_WORKFLOW);
  try {
    const researchDeployText = await readFile(researchDeployPath, 'utf8');
    if (!researchDeployText.includes('verify-seo-routing.sh')) {
      errors.push('research-deploy.yml must retain verify-seo-routing.sh post-deploy check');
    }
  } catch {
    errors.push(`missing workflow: ${researchDeployPath}`);
  }

  const runbookPath = join(repoRoot, RUNBOOK_PATH);
  try {
    const runbookText = await readFile(runbookPath, 'utf8');
    const requiredRunbookSnippets = [
      'frontend-deploy',
      'verify-seo-routing.sh',
      'frontend-deploy CI',
    ];
    for (const snippet of requiredRunbookSnippets) {
      if (!runbookText.includes(snippet)) {
        errors.push(`runbook missing required snippet: ${snippet}`);
      }
    }
    if (runbookText.includes('HTTP 検証 | **手動**（デプロイ後） | `verify-seo-routing.sh`')) {
      errors.push('runbook §3 must document frontend-deploy CI automation for HTTP verification');
    }
  } catch {
    errors.push(`missing runbook: ${runbookPath}`);
  }

  return { ok: errors.length === 0, errors };
}

/**
 * @param {string} workflowText
 * @param {string} stepName
 * @returns {string}
 */
function extractStepBlock(workflowText, stepName) {
  const start = workflowText.indexOf(`- name: ${stepName}`);
  if (start === -1) {
    return '';
  }
  const nextStep = workflowText.indexOf('\n      - name:', start + 1);
  return nextStep === -1 ? workflowText.slice(start) : workflowText.slice(start, nextStep);
}
