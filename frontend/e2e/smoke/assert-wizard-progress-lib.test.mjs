import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  WIZARD_PROGRESS_MIN_HEIGHT_PX,
  WIZARD_PROGRESS_ROOT_SELECTOR,
  compareWizardProgressLayouts,
  evaluateWizardProgressFlexStyle,
} from './assert-wizard-progress-lib.mjs';

test('WIZARD_PROGRESS_ROOT_SELECTOR targets compact-progress bar', () => {
  assert.equal(WIZARD_PROGRESS_ROOT_SELECTOR, '.compact-progress');
});

test('evaluateWizardProgressFlexStyle passes valid flex layout', () => {
  assert.deepEqual(
    evaluateWizardProgressFlexStyle({ display: 'flex', minHeight: '44px' }),
    [],
  );
});

test('evaluateWizardProgressFlexStyle rejects non-flex display', () => {
  const violations = evaluateWizardProgressFlexStyle({ display: 'block', minHeight: '44px' });
  assert.ok(violations.some((v) => v.includes('display')));
});

test('evaluateWizardProgressFlexStyle rejects min-height below threshold', () => {
  const violations = evaluateWizardProgressFlexStyle({ display: 'flex', minHeight: '32px' });
  assert.ok(violations.some((v) => v.includes('min-height')));
  assert.ok(violations.some((v) => v.includes(String(WIZARD_PROGRESS_MIN_HEIGHT_PX))));
});

test('compareWizardProgressLayouts detects display mismatch', () => {
  const violations = compareWizardProgressLayouts(
    { display: 'flex', minHeightPx: 44 },
    { display: 'block', minHeightPx: 44 },
  );
  assert.ok(violations.some((v) => v.includes('display mismatch')));
});

test('compareWizardProgressLayouts detects min-height mismatch', () => {
  const violations = compareWizardProgressLayouts(
    { display: 'flex', minHeightPx: 44 },
    { display: 'flex', minHeightPx: 32 },
  );
  assert.ok(violations.some((v) => v.includes('min-height mismatch')));
});

test('compareWizardProgressLayouts passes identical layouts', () => {
  assert.deepEqual(
    compareWizardProgressLayouts(
      { display: 'flex', minHeightPx: 44 },
      { display: 'flex', minHeightPx: 44 },
    ),
    [],
  );
});
