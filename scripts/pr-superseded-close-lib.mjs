/**
 * Mechanical superseded open PR detection (title match against merged PRs; no body parse).
 */

/**
 * @param {string | null | undefined} title
 * @returns {string}
 */
export function normalizePrTitle(title) {
  return (title ?? '').trim().replace(/\s+/g, ' ');
}

/**
 * Open PR is superseded when a merged PR has the same normalized title.
 *
 * @param {Array<{ number: number; title: string }>} openPrs
 * @param {Array<{ number: number; title: string }>} mergedPrs
 * @returns {Array<{ number: number; title: string; supersededBy: number }>}
 */
export function findSupersededOpenPrs(openPrs, mergedPrs) {
  /** @type {Map<string, { number: number; title: string }>} */
  const mergedByTitle = new Map();
  for (const merged of mergedPrs) {
    const key = normalizePrTitle(merged.title);
    if (!key) {
      continue;
    }
    const existing = mergedByTitle.get(key);
    if (!existing || merged.number > existing.number) {
      mergedByTitle.set(key, merged);
    }
  }

  /** @type {Array<{ number: number; title: string; supersededBy: number }>} */
  const superseded = [];
  for (const open of openPrs) {
    const key = normalizePrTitle(open.title);
    const winner = mergedByTitle.get(key);
    if (winner && winner.number !== open.number) {
      superseded.push({
        number: open.number,
        title: open.title,
        supersededBy: winner.number,
      });
    }
  }
  return superseded.sort((a, b) => a.number - b.number);
}
