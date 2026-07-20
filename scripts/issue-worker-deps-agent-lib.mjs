export const AGENT_DEPS_READY_LABEL = 'agent-deps-ready';
export const AGENT_DEPS_WAIT_LABEL_PREFIX = 'agent-deps-wait-';

/**
 * @param {string | string[] | Array<{ name?: string }>} labels
 * @returns {string[]}
 */
export function normalizeLabelNames(labels) {
  if (Array.isArray(labels)) {
    return labels
      .map((label) => (typeof label === 'string' ? label : (label?.name ?? '')))
      .filter(Boolean);
  }
  if (!labels) {
    return [];
  }
  return labels
    .split(',')
    .map((name) => name.trim())
    .filter(Boolean);
}

/**
 * @param {number} issueNumber
 * @returns {string}
 */
export function agentDepsWaitLabel(issueNumber) {
  return `${AGENT_DEPS_WAIT_LABEL_PREFIX}${issueNumber}`;
}

/**
 * @param {string | string[] | Array<{ name?: string }>} labels
 * @returns {boolean}
 */
export function hasAgentDepsReadyLabel(labels) {
  return normalizeLabelNames(labels).includes(AGENT_DEPS_READY_LABEL);
}

/**
 * Machine-readable hard dependency wait labels (GitHub API labels only; no comment parse).
 *
 * @param {string | string[] | Array<{ name?: string }>} labels
 * @returns {number[]}
 */
export function parseAgentDepsWaitIssueNumbers(labels) {
  const names = normalizeLabelNames(labels);
  /** @type {number[]} */
  const result = [];
  for (const name of names) {
    if (!name.startsWith(AGENT_DEPS_WAIT_LABEL_PREFIX)) {
      continue;
    }
    const issueNumber = Number(name.slice(AGENT_DEPS_WAIT_LABEL_PREFIX.length));
    if (Number.isInteger(issueNumber) && issueNumber > 0) {
      result.push(issueNumber);
    }
  }
  return [...new Set(result)].sort((a, b) => a - b);
}

/**
 * @param {string | string[] | Array<{ name?: string }>} labels
 * @returns {boolean}
 */
export function isAgentDepsLabelCacheHit(labels) {
  return hasAgentDepsReadyLabel(labels);
}
