import assert from 'node:assert/strict';
import test from 'node:test';

import {
  UX_CAMPAIGN_BREADCRUMB_LABEL,
  extractClosingIssueNumbers,
  issueLabelsIncludeUxCampaign,
  shouldRunUxCampaignPostMerge,
  shouldTreatMergedPrAsPostMergeOnly,
} from './delivery-agent-campaign-lib.mjs';

test('UX_CAMPAIGN_BREADCRUMB_LABEL is ux-campaign:breadcrumb', () => {
  assert.equal(UX_CAMPAIGN_BREADCRUMB_LABEL, 'ux-campaign:breadcrumb');
});

test('issueLabelsIncludeUxCampaign accepts string[] and {name}[]', () => {
  assert.equal(issueLabelsIncludeUxCampaign(['ux-campaign:breadcrumb']), true);
  assert.equal(
    issueLabelsIncludeUxCampaign([{ name: 'ux-campaign:breadcrumb' }]),
    true,
  );
  assert.equal(issueLabelsIncludeUxCampaign(['agent-ready']), false);
});

test('extractClosingIssueNumbers uses GitHub closingIssuesReferences shape only', () => {
  assert.deepEqual(
    extractClosingIssueNumbers([
      { number: 321, repository: { name: 'agrr' } },
      { number: 321 },
      { number: 0 },
      {},
    ]),
    [321],
  );
  assert.deepEqual(extractClosingIssueNumbers(null), []);
});

test('shouldRunUxCampaignPostMerge requires merged PR and campaign label on a linked issue', () => {
  assert.equal(
    shouldRunUxCampaignPostMerge({
      prMerged: true,
      linkedIssues: [{ labels: ['agent-ready'] }],
    }),
    false,
  );
  assert.equal(
    shouldRunUxCampaignPostMerge({
      prMerged: true,
      linkedIssues: [{ labels: ['ux-campaign:breadcrumb', 'agent-ready'] }],
    }),
    true,
  );
  assert.equal(
    shouldRunUxCampaignPostMerge({
      prMerged: false,
      linkedIssues: [{ labels: ['ux-campaign:breadcrumb'] }],
    }),
    false,
  );
});

test('shouldTreatMergedPrAsPostMergeOnly is true only when PR is already merged', () => {
  assert.equal(shouldTreatMergedPrAsPostMergeOnly({ merged: true }), true);
  assert.equal(shouldTreatMergedPrAsPostMergeOnly({ merged: false }), false);
  assert.equal(shouldTreatMergedPrAsPostMergeOnly({}), false);
});
