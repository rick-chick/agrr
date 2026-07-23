/**
 * Canonical Delivery Agent Automation prompt and prefill URL builder.
 * Keep in sync with `.cursor/skills/delivery-agent/SKILL.md` § Automation.
 */

/** Live Delivery Agent automation in Cursor Dashboard. */
export const DELIVERY_AGENT_AUTOMATION_ID = '6a5cb2d9-8317-11f1-a7d1-d6b4613131ce';

/** @type {string} */
export const DELIVERY_AGENT_AUTOMATION_PROMPT = `Read \`.cursor/skills/delivery-agent/SKILL.md\` exactly.
Payload: repository, issue_number, pr_number (optional). Optional: pr_unlinked — do not trust; observe GitHub with gh and decide.
No action field — if present, ignore it. Never skip because of merge-prohibition labels.
Open PR: decide merge or close; do not leave open without action.
Use referenced skills for implement and merge paths.
After TDD GREEN on issue implement path, run sequential-cleanup-review-workflow §4
(cleanup-workflow-tick.sh) before opening a PR. Do not skip tick or open PR before gate exit 0.
After gh pr merge succeeds, if a linked issue has ux-campaign:breadcrumb, continue the same run
with ux-campaign-loop §1–§2 (post-merge). Never disable the Delivery Agent automation.`;

const DELIVERY_AGENT_PREFILL_BASE = {
  name: 'AGRR Delivery Agent (Webhook)',
  description:
    'rick-chick/agrr issue/PR を Delivery Agent — webhook のみ、action なし payload',
  workflow: {
    triggers: [{ webhook: {} }],
    prompts: [{ prompt: DELIVERY_AGENT_AUTOMATION_PROMPT }],
  },
  gitConfig: {
    repo: 'https://github.com/rick-chick/agrr',
    repos: ['https://github.com/rick-chick/agrr'],
    branch: 'master',
  },
  memoryEnabled: true,
  agentOptions: { openPullRequest: true },
};

/**
 * @returns {string}
 */
export function buildDeliveryAgentPrefillToken() {
  const json = JSON.stringify(DELIVERY_AGENT_PREFILL_BASE);
  return Buffer.from(json, 'utf8')
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

/**
 * @returns {string}
 */
export function buildDeliveryAgentPrefillUrl() {
  return `https://cursor.com/automations/new?prefill=${buildDeliveryAgentPrefillToken()}`;
}

/**
 * One-click apply URL for the live Delivery Agent automation.
 * Opens the existing automation with canonical prompt pre-filled — user only saves.
 *
 * @param {string} [automationId]
 * @returns {string}
 */
export function buildDeliveryAgentAutomationApplyUrl(
  automationId = DELIVERY_AGENT_AUTOMATION_ID,
) {
  return `https://cursor.com/automations/${automationId}?prefill=${buildDeliveryAgentPrefillToken()}`;
}

/**
 * @param {string} prefillToken
 * @returns {{ prompt: string }}
 */
export function decodeDeliveryAgentPrefillToken(prefillToken) {
  const normalized = prefillToken.replace(/-/g, '+').replace(/_/g, '/');
  const padding = '='.repeat((4 - (normalized.length % 4)) % 4);
  const json = Buffer.from(normalized + padding, 'base64').toString('utf8');
  const data = JSON.parse(json);
  const prompt = data?.workflow?.prompts?.[0]?.prompt;
  if (typeof prompt !== 'string') {
    throw new Error('delivery agent prefill missing workflow.prompts[0].prompt');
  }
  return { prompt };
}
