import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  findAwkwardEnTitleIssues,
  findMajorPestsCropAlignmentIssues,
} from './research-major-pests-crop-alignment-lib.mjs';

test('findMajorPestsCropAlignmentIssues flags onion content on cabbage', () => {
  const issues = findMajorPestsCropAlignmentIssues(
    'cabbage',
    'Major Onion Pests Worldwide. Onion (Allium cepa) is an important crop.'
  );
  assert.ok(issues.some((issue) => issue.includes('forbidden')));
});

test('findMajorPestsCropAlignmentIssues allows related pest names on radish', () => {
  const issues = findMajorPestsCropAlignmentIssues(
    'radish',
    'Major Radish Pests Worldwide. Cabbage root fly (Delia spp.) can damage radish (Raphanus sativus) roots.'
  );
  assert.deepEqual(issues, []);
});

test('findMajorPestsCropAlignmentIssues passes cabbage content', () => {
  const issues = findMajorPestsCropAlignmentIssues(
    'cabbage',
    'Major Cabbage Pests Worldwide. Cabbage (Brassica oleracea) suffers from diamondback moth.'
  );
  assert.deepEqual(issues, []);
});

test('findMajorPestsCropAlignmentIssues flags cabbage content on radish', () => {
  const issues = findMajorPestsCropAlignmentIssues(
    'radish',
    'Major Cabbage Pests Worldwide. Cabbage (Brassica oleracea var. capitata) is widely grown.'
  );
  assert.ok(issues.length > 0);
});

test('findAwkwardEnTitleIssues flags machine slug titles', () => {
  const issues = findAwkwardEnTitleIssues(
    'Comprehensive explanation of cumulative temperature-gdd-requirements for each growth stage of corn'
  );
  assert.deepEqual(issues, ['awkward machine-translated title']);
});
