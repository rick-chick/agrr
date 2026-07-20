import { buildDeliveryIssuePayload } from './delivery-dispatch-lib.mjs';

/**
 * @param {string[]} argv
 * @returns {{ repo: string; number: number }}
 */
export function parseDepsResolveArgs(argv) {
  let repo = 'rick-chick/agrr';
  let number = 0;
  for (let i = 2; i < argv.length; i += 1) {
    if (argv[i] === '--repo') {
      repo = argv[i + 1] ?? repo;
      i += 1;
      continue;
    }
    if (argv[i] === '--number') {
      number = Number(argv[i + 1]);
      i += 1;
    }
  }
  if (!Number.isInteger(number) || number <= 0) {
    throw new Error('--number must be a positive integer');
  }
  return { repo, number };
}

/**
 * Delivery Agent deps-only run: repository + issue fields (no action, no body_hash).
 *
 * @param {{
 *   repo: string;
 *   issueNumber: number;
 *   issueTitle: string;
 *   issueUrl: string;
 * }} input
 * @returns {Record<string, unknown>}
 */
export function buildDepsResolveWebhookPayload(input) {
  return buildDeliveryIssuePayload({
    repository: input.repo,
    issueNumber: input.issueNumber,
    issueTitle: input.issueTitle,
    issueUrl: input.issueUrl,
  });
}

/**
 * @param {NodeJS.ProcessEnv} [env]
 * @returns {{ configured: boolean; url: string; key: string }}
 */
export function resolveDepsAgentWebhookEnv(env = process.env) {
  const url = env.CURSOR_DELIVERY_WEBHOOK_URL ?? '';
  const key = env.CURSOR_DELIVERY_WEBHOOK_KEY ?? '';
  return {
    configured: Boolean(url && key),
    url,
    key,
  };
}
