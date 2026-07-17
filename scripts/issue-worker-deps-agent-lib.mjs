import { createHash } from 'node:crypto';

export const AGENT_DEPS_MARKER = 'agent-deps:v1';

/**
 * @param {string} issueBody
 * @returns {string | null}
 */
export function extractDependencySection(issueBody) {
  const lines = issueBody.split(/\r?\n/);
  const startIndex = lines.findIndex((line) => /^## 依存[ \t]*$/.test(line));
  if (startIndex === -1) {
    return null;
  }
  const sectionLines = [];
  for (let i = startIndex + 1; i < lines.length; i += 1) {
    if (/^## /.test(lines[i])) {
      break;
    }
    sectionLines.push(lines[i]);
  }
  return sectionLines.join('\n').trimEnd();
}

/**
 * @param {string} issueBody
 * @returns {string}
 */
export function hashDependencySection(issueBody) {
  const section = extractDependencySection(issueBody);
  return createHash('sha256').update(section ?? '').digest('hex');
}

/**
 * @param {unknown} value
 * @returns {value is {
 *   hard_dependencies: number[];
 *   soft_notes: string[];
 *   rationale: string;
 *   body_hash: string;
 * }}
 */
export function isAgentDepsContract(value) {
  if (!value || typeof value !== 'object') {
    return false;
  }
  const contract = /** @type {Record<string, unknown>} */ (value);
  if (!Array.isArray(contract.hard_dependencies)) {
    return false;
  }
  if (!contract.hard_dependencies.every((entry) => Number.isInteger(entry) && entry > 0)) {
    return false;
  }
  if (!Array.isArray(contract.soft_notes) || !contract.soft_notes.every((entry) => typeof entry === 'string')) {
    return false;
  }
  if (typeof contract.rationale !== 'string' || contract.rationale.trim() === '') {
    return false;
  }
  if (typeof contract.body_hash !== 'string' || contract.body_hash.trim() === '') {
    return false;
  }
  return true;
}

/**
 * @param {string} commentBody
 * @returns {{
 *   hard_dependencies: number[];
 *   soft_notes: string[];
 *   rationale: string;
 *   body_hash: string;
 * } | null}
 */
export function parseAgentDepsFromCommentBody(commentBody) {
  const markerPattern = new RegExp(
    `<!--\\s*${AGENT_DEPS_MARKER.replace(':', '\\:')}\\s+(\\{[\\s\\S]*?\\})\\s*-->`,
  );
  const match = commentBody.match(markerPattern);
  if (!match) {
    return null;
  }
  try {
    const parsed = JSON.parse(match[1]);
    return isAgentDepsContract(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

/**
 * @param {Array<{ body?: string; createdAt?: string }>} comments newest-first or any order
 * @returns {{
 *   hard_dependencies: number[];
 *   soft_notes: string[];
 *   rationale: string;
 *   body_hash: string;
 * } | null}
 */
export function parseAgentDepsFromComments(comments) {
  const sorted = [...comments].sort((a, b) => {
    const aTime = Date.parse(a.createdAt ?? '') || 0;
    const bTime = Date.parse(b.createdAt ?? '') || 0;
    return bTime - aTime;
  });
  for (const comment of sorted) {
    const contract = parseAgentDepsFromCommentBody(comment.body ?? '');
    if (contract) {
      return contract;
    }
  }
  return null;
}

/**
 * @param {{
 *   hard_dependencies: number[];
 *   soft_notes: string[];
 *   rationale: string;
 *   body_hash: string;
 * }} contract
 * @returns {string}
 */
export function buildAgentDepsCacheComment(contract) {
  const payload = JSON.stringify({
    hard_dependencies: [...contract.hard_dependencies].sort((a, b) => a - b),
    soft_notes: contract.soft_notes,
    rationale: contract.rationale,
    body_hash: contract.body_hash,
  });
  return [
    '## 🤖 Issue Worker: 依存判定（Agent）',
    '',
    contract.rationale,
    '',
    `<!-- ${AGENT_DEPS_MARKER} ${payload} -->`,
  ].join('\n');
}

/**
 * @param {{
 *   hard_dependencies: number[];
 *   soft_notes: string[];
 *   rationale: string;
 *   body_hash: string;
 * }} contract
 * @param {string} issueBody
 * @returns {boolean}
 */
export function isAgentDepsCacheValid(contract, issueBody) {
  return contract.body_hash === hashDependencySection(issueBody);
}

/**
 * @param {(issueNumber: number) => Promise<Array<{ body?: string; createdAt?: string }>> | Array<{ body?: string; createdAt?: string }>} fetchComments
 * @returns {(issueNumber: number, issueBody: string) => Promise<{
 *   hard_dependencies: number[];
 *   soft_notes: string[];
 *   rationale: string;
 *   body_hash: string;
 * } | null>}
 */
export function createGetAgentDepsContractFromComments(fetchComments) {
  return async (issueNumber, issueBody) => {
    const comments = await fetchComments(issueNumber);
    const contract = parseAgentDepsFromComments(comments);
    if (!contract || !isAgentDepsCacheValid(contract, issueBody)) {
      return null;
    }
    return contract;
  };
}
