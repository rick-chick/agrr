/**
 * Resolve an open PR for workflow_run (Backend test completed) with fallbacks
 * when commits/SHA/pulls returns HTML or fails.
 */

/**
 * @param {Array<Record<string, unknown>>} prs
 * @returns {Array<Record<string, unknown>>}
 */
function openPrsOnly(prs) {
  return prs.filter((pr) => pr.state === 'open' || pr.state === undefined);
}

/**
 * @param {{
 *   headSha: string;
 *   workflowRunPullRequests?: Array<{ number?: number }>;
 *   fetchCommitPulls?: () => unknown;
 *   fetchPrView?: (prNumber: number) => Record<string, unknown>;
 *   fetchPrListByHeadOid?: (headSha: string) => unknown;
 * }} input
 * @returns {{ skip: true; skipReason: string } | { skip: false; pr: Record<string, unknown> }}
 */
export function resolveWorkflowRunPr(input) {
  const { headSha } = input;
  /** @type {Array<Record<string, unknown>>} */
  let openPrs = [];

  if (input.fetchCommitPulls) {
    try {
      const raw = input.fetchCommitPulls();
      if (Array.isArray(raw)) {
        openPrs = openPrsOnly(raw);
      }
    } catch {
      // commits/SHA/pulls may fail (permissions, HTML error page, etc.)
    }
  }

  if (
    openPrs.length === 0 &&
    input.workflowRunPullRequests?.length &&
    input.fetchPrView
  ) {
    const prNumber = Number(input.workflowRunPullRequests[0].number);
    if (Number.isInteger(prNumber) && prNumber > 0) {
      try {
        const pr = input.fetchPrView(prNumber);
        if (pr && typeof pr === 'object' && pr.state !== 'closed') {
          return { skip: false, pr };
        }
      } catch {
        // fall through to headRefOid list
      }
    }
  }

  if (openPrs.length === 0 && input.fetchPrListByHeadOid) {
    try {
      const raw = input.fetchPrListByHeadOid(headSha);
      if (Array.isArray(raw)) {
        openPrs = openPrsOnly(raw);
      }
    } catch {
      // gh pr list may fail; handled below
    }
  }

  if (openPrs.length === 0) {
    return {
      skip: true,
      skipReason: `No open PR found for commit ${headSha}`,
    };
  }

  if (openPrs.length > 1) {
    return {
      skip: true,
      skipReason: `Multiple open PRs for commit ${headSha}; skipping ambiguous dispatch`,
    };
  }

  return { skip: false, pr: openPrs[0] };
}

/**
 * @param {Record<string, unknown>} pr
 * @returns {{
 *   number: number;
 *   headRef: string;
 *   title: string;
 *   labels: string;
 *   url: string;
 *   author: string;
 * }}
 */
export function mapWorkflowRunPrFields(pr) {
  const labels = Array.isArray(pr.labels)
    ? pr.labels.map((label) => {
        if (typeof label === 'string') {
          return label;
        }
        if (label && typeof label === 'object' && 'name' in label) {
          return String(/** @type {{ name: string }} */ (label).name);
        }
        return '';
      }).filter(Boolean)
    : [];

  const headRef =
    typeof pr.head?.ref === 'string'
      ? pr.head.ref
      : typeof pr.headRefName === 'string'
        ? pr.headRefName
        : '';

  const authorLogin =
    pr.user && typeof pr.user === 'object' && 'login' in pr.user
      ? String(/** @type {{ login: string }} */ (pr.user).login)
      : typeof pr.author === 'string'
        ? pr.author
        : pr.author &&
            typeof pr.author === 'object' &&
            'login' in pr.author
          ? String(/** @type {{ login: string }} */ (pr.author).login)
          : '';

  return {
    number: Number(pr.number),
    headRef,
    title: typeof pr.title === 'string' ? pr.title : '',
    labels: labels.join(','),
    url: typeof pr.html_url === 'string' ? pr.html_url : typeof pr.url === 'string' ? pr.url : '',
    author: authorLogin,
  };
}
