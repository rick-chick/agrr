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
