import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  WIZARD_PROGRESS_MIN_HEIGHT_PX,
  WIZARD_PROGRESS_REQUIRED_DISPLAY,
  WIZARD_PROGRESS_SELECTORS,
  checkWizardProgressElementLayout,
  compareWizardProgressLayouts,
  expectWizardProgressLayoutsMatch,
  normalizeWizardProgressLayout,
} from './assert-wizard-progress-lib.mjs';

test('WIZARD_PROGRESS_SELECTORS includes compact-progress', () => {
  assert.ok(WIZARD_PROGRESS_SELECTORS.includes('.compact-progress'));
});

test('checkWizardProgressElementLayout passes flex with sufficient height', () => {
  const violations = checkWizardProgressElementLayout({
    selector: '.compact-progress',
    display: WIZARD_PROGRESS_REQUIRED_DISPLAY,
    heightPx: WIZARD_PROGRESS_MIN_HEIGHT_PX,
  });
  assert.deepEqual(violations, []);
});

test('checkWizardProgressElementLayout fails on non-flex display', () => {
  const violations = checkWizardProgressElementLayout({
    selector: '.compact-progress',
    display: 'block',
    heightPx: 44,
  });
  assert.ok(violations.some((v) => v.includes('display=block')));
});

test('checkWizardProgressElementLayout fails when height below threshold', () => {
  const violations = checkWizardProgressElementLayout({
    selector: '.compact-progress',
    display: 'flex',
    heightPx: WIZARD_PROGRESS_MIN_HEIGHT_PX - 1,
  });
  assert.ok(violations.some((v) => v.includes(`${WIZARD_PROGRESS_MIN_HEIGHT_PX}px`)));
});

test('normalizeWizardProgressLayout records display and minHeightPx', () => {
  assert.deepEqual(
    normalizeWizardProgressLayout({ display: 'flex', heightPx: 44 }),
    { display: 'flex', minHeightPx: 44 },
  );
});

test('compareWizardProgressLayouts detects display mismatch', () => {
  const violations = compareWizardProgressLayouts(
    { display: 'flex', minHeightPx: 44 },
    { display: 'block', minHeightPx: 44 },
  );
  assert.ok(violations.some((v) => v.includes('display mismatch')));
});

test('compareWizardProgressLayouts detects minHeight mismatch', () => {
  const violations = compareWizardProgressLayouts(
    { display: 'flex', minHeightPx: 44 },
    { display: 'flex', minHeightPx: 40 },
  );
  assert.ok(violations.some((v) => v.includes('minHeight mismatch')));
});

test('expectWizardProgressLayoutsMatch throws with joined violations', () => {
  assert.throws(
    () =>
      expectWizardProgressLayoutsMatch(
        { display: 'flex', minHeightPx: 44 },
        { display: 'flex', minHeightPx: 40 },
      ),
    /minHeight mismatch/,
  );
});

test('expectWizardProgressLayoutsMatch passes when layouts match', () => {
  expectWizardProgressLayoutsMatch(
    { display: 'flex', minHeightPx: 44 },
    { display: 'flex', minHeightPx: 44 },
  );
});
