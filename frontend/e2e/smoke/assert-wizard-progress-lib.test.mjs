import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  expectWizardProgressLayoutsMatch,
  resolveWizardProgressMinHeightPx,
  validateWizardProgressLayout,
  WIZARD_PROGRESS_MIN_HEIGHT_PX,
  wizardProgressLayoutsMatch,
} from './wizard-progress-contract.mjs';

test('validateWizardProgressLayout requires flex display and min-height threshold', () => {
  assert.deepEqual(validateWizardProgressLayout('flex', 44), []);
  assert.ok(validateWizardProgressLayout('block', 44).some((v) => v.includes('display')));
  assert.ok(
    validateWizardProgressLayout('flex', WIZARD_PROGRESS_MIN_HEIGHT_PX - 1).some((v) =>
      v.includes('min-height'),
    ),
  );
  assert.deepEqual(validateWizardProgressLayout('flex', WIZARD_PROGRESS_MIN_HEIGHT_PX), []);
});

test('wizardProgressLayoutsMatch compares display and minHeightPx', () => {
  const a = { selector: '.a', display: 'flex', minHeightPx: 44 };
  const b = { selector: '.b', display: 'flex', minHeightPx: 44 };
  const c = { selector: '.c', display: 'flex', minHeightPx: 32 };

  assert.equal(wizardProgressLayoutsMatch(a, b), true);
  assert.equal(wizardProgressLayoutsMatch(a, c), false);
});

test('expectWizardProgressLayoutsMatch detects min-height mismatch across routes', () => {
  const violations = expectWizardProgressLayoutsMatch([
    { selector: '.compact-progress', display: 'flex', minHeightPx: 44 },
    { selector: '.compact-progress', display: 'flex', minHeightPx: 32 },
  ]);

  assert.ok(violations.some((v) => v.includes('minHeight=32px')));
});

test('expectWizardProgressLayoutsMatch detects display mismatch across routes', () => {
  const violations = expectWizardProgressLayoutsMatch([
    { selector: '.compact-progress', display: 'flex', minHeightPx: 44 },
    { selector: '.compact-progress', display: 'block', minHeightPx: 44 },
  ]);

  assert.ok(violations.some((v) => v.includes('display=block')));
});

test('resolveWizardProgressMinHeightPx prefers computed min-height over bounding rect', () => {
  assert.equal(resolveWizardProgressMinHeightPx({ minHeight: '44px' }, 20), 44);
  assert.equal(resolveWizardProgressMinHeightPx({ minHeight: 'auto' }, 44), 44);
});
