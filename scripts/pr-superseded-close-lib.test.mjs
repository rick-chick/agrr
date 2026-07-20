import assert from 'node:assert/strict';
import { test } from 'node:test';

import { findSupersededOpenPrs, normalizePrTitle } from './pr-superseded-close-lib.mjs';

test('normalizePrTitle trims and collapses whitespace', () => {
  assert.equal(normalizePrTitle('  fix: foo  \n bar '), 'fix: foo bar');
});

test('findSupersededOpenPrs flags open PR when merged PR has same title', () => {
  const superseded = findSupersededOpenPrs(
    [
      { number: 431, title: 'fix(automation): align Delivery Agent PR webhook payload with contract' },
      { number: 433, title: 'fix(automation): align Delivery Agent PR webhook payload with contract' },
      { number: 437, title: 'docs(agent-review): capture' },
    ],
    [
      { number: 434, title: 'fix(automation): align Delivery Agent PR webhook payload with contract' },
    ],
  );
  assert.deepEqual(superseded, [
    {
      number: 431,
      title: 'fix(automation): align Delivery Agent PR webhook payload with contract',
      supersededBy: 434,
    },
    {
      number: 433,
      title: 'fix(automation): align Delivery Agent PR webhook payload with contract',
      supersededBy: 434,
    },
  ]);
});

test('findSupersededOpenPrs flags open PR when merged PR closed same issue', () => {
  const superseded = findSupersededOpenPrs(
    [
      {
        number: 436,
        title: 'feat: different title on parallel branch',
        closingIssuesReferences: [{ number: 320 }],
      },
    ],
    [
      {
        number: 439,
        title: 'fix: merged under another title',
        closingIssuesReferences: [{ number: 320 }],
      },
    ],
  );
  assert.deepEqual(superseded, [
    {
      number: 436,
      title: 'feat: different title on parallel branch',
      supersededBy: 439,
    },
  ]);
});

test('findSupersededOpenPrs ignores open PR with unique title', () => {
  const superseded = findSupersededOpenPrs(
    [{ number: 437, title: 'docs(agent-review): capture' }],
    [{ number: 434, title: 'fix(automation): other' }],
  );
  assert.deepEqual(superseded, []);
});
