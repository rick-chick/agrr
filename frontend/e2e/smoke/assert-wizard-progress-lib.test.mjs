import assert from 'node:assert/strict';
import { test } from 'node:test';

import { collectWizardProgressLayouts } from './assert-wizard-progress-lib.mjs';
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

test('collectWizardProgressLayouts defaults selectors for Playwright serialization', async () => {
  const { JSDOM } = await import('jsdom');
  const dom = new JSDOM(
    `<!DOCTYPE html><html><body><div id="host"><div class="compact-progress" style="display:flex;min-height:44px;width:200px;height:44px;"></div></div></body></html>`,
    { pretendToBeVisual: true },
  );
  const previousDocument = globalThis.document;
  globalThis.document = dom.window.document;
  Object.defineProperty(dom.window.HTMLElement.prototype, 'getBoundingClientRect', {
    configurable: true,
    value() {
      return { width: 200, height: 44, top: 0, left: 0, right: 200, bottom: 44, x: 0, y: 0 };
    },
  });

  try {
    const result = collectWizardProgressLayouts({ hostSelector: '#host' });
    assert.equal(result.violations.length, 0);
    assert.equal(result.layouts.length, 1);
  } finally {
    globalThis.document = previousDocument;
  }
});

test('resolveWizardProgressMinHeightPx prefers computed min-height over bounding rect', () => {
  assert.equal(resolveWizardProgressMinHeightPx({ minHeight: '44px' }, 20), 44);
  assert.equal(resolveWizardProgressMinHeightPx({ minHeight: 'auto' }, 44), 44);
});
