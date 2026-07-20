export const UX_CAMPAIGN_BREADCRUMB_LABEL = 'ux-campaign:breadcrumb';

/**
 * @param {Array<string | { name?: string }> | null | undefined} labels
 * @returns {boolean}
 */
export function issueLabelsIncludeUxCampaign(labels) {
  if (!Array.isArray(labels)) {
    return false;
  }
  return labels.some((label) => {
    const name = typeof label === 'string' ? label : label?.name;
    return name === UX_CAMPAIGN_BREADCRUMB_LABEL;
  });
}

/**
 * @param {Array<{ number?: number }> | null | undefined} closingIssuesReferences
 * @returns {number[]}
 */
export function extractClosingIssueNumbers(closingIssuesReferences) {
  if (!Array.isArray(closingIssuesReferences)) {
    return [];
  }
  const numbers = closingIssuesReferences
    .map((ref) => ref?.number)
    .filter((number) => Number.isInteger(number) && number > 0);
  return [...new Set(numbers)];
}

/**
 * @param {{ prMerged: boolean; linkedIssues: Array<{ labels?: Array<string | { name?: string }> }> }}
 * @returns {boolean}
 */
export function shouldRunUxCampaignPostMerge({ prMerged, linkedIssues }) {
  if (!prMerged) {
    return false;
  }
  return linkedIssues.some((issue) =>
    issueLabelsIncludeUxCampaign(issue.labels),
  );
}

/**
 * @param {{ merged?: boolean }}
 * @returns {boolean}
 */
export function shouldTreatMergedPrAsPostMergeOnly({ merged }) {
  return merged === true;
}
