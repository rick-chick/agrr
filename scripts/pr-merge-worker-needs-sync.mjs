/**
 * Whether an eligible PR should receive a conflict / master-sync dispatch
 * after master advances.
 *
 * @param {{ mergeable?: string | null; mergeStateStatus?: string | null }} pr
 * @returns {boolean}
 */
export function prMergeWorkerNeedsSync(pr) {
  const mergeable = pr.mergeable ?? '';
  const mergeStateStatus = pr.mergeStateStatus ?? '';

  if (mergeStateStatus === 'DIRTY') return true;
  if (mergeable === 'CONFLICTING') return true;
  if (mergeStateStatus === 'BEHIND') return true;

  return false;
}

/**
 * @param {string} labelsCsv
 * @param {string} headRef
 * @param {string} body
 * @returns {boolean}
 */
export function prMergeWorkerIsEligible(labelsCsv, headRef, body = '') {
  if (/(^|,)agent-merge(,|$)/.test(labelsCsv)) return true;
  if (/^issue\/[0-9]+-/.test(headRef)) return true;
  if (body.includes('Merge-Strategy: agent')) return true;
  return false;
}

/**
 * @param {string} labelsCsv
 * @returns {boolean}
 */
export function prMergeWorkerHasBlockingLabel(labelsCsv) {
  return /(^|,)agent-no-merge(,|$)|(^|,)do-not-merge(,|$)|(^|,)wip(,|$)|(^|,)agent-merge-blocked(,|$)/.test(
    labelsCsv,
  );
}

/**
 * @param {string} labelsCsv
 * @returns {boolean}
 */
export function prMergeWorkerShouldSkipInProgress(labelsCsv) {
  return /(^|,)agent-merge-in-progress(,|$)/.test(labelsCsv);
}

/**
 * @param {Array<Record<string, unknown>>} prs
 * @returns {Array<Record<string, unknown>>}
 */
export function selectSyncCandidates(prs) {
  return prs.filter((pr) => {
    const labels = Array.isArray(pr.labels)
      ? pr.labels.map((label) => label.name).join(',')
      : '';
    const headRef = String(pr.headRefName ?? '');
    const body = String(pr.body ?? '');
    const title = String(pr.title ?? '');

    if (!prMergeWorkerIsEligible(labels, headRef, body)) return false;
    if (pr.isDraft === true) return false;
    if (prMergeWorkerHasBlockingLabel(labels)) return false;
    if (prMergeWorkerShouldSkipInProgress(labels)) return false;

    if (pr.isCrossRepository === true) return false;

    if (pr.reviewDecision === 'CHANGES_REQUESTED') return false;
    if (/\[(WIP|DRAFT)\]/i.test(title)) return false;

    const total = Number(pr.additions ?? 0) + Number(pr.deletions ?? 0);
    if (total > 800 && !/(^|,)agent-merge(,|$)/.test(labels)) return false;

    return prMergeWorkerNeedsSync({
      mergeable: String(pr.mergeable ?? ''),
      mergeStateStatus: String(pr.mergeStateStatus ?? ''),
    });
  });
}
