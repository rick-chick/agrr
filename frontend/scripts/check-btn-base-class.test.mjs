import assert from 'node:assert/strict';
import { test } from 'node:test';

import { findBtnVariantWithoutBase, lineNumberForOffset } from './check-btn-base-class-lib.mjs';

test('lineNumberForOffset counts newline boundaries', () => {
  const text = 'one\ntwo\nthree';
  assert.equal(lineNumberForOffset(text, 0), 1);
  assert.equal(lineNumberForOffset(text, 4), 2);
  assert.equal(lineNumberForOffset(text, 8), 3);
});

test('findBtnVariantWithoutBase flags variant-only class attributes', () => {
  const text = `
    <button class="btn-primary">Save</button>
    <a class="btn-secondary foo">Cancel</a>
    <button class="btn btn-danger">Delete</button>
  `;
  const violations = findBtnVariantWithoutBase(text, 'sample.component.ts');
  assert.equal(violations.length, 2);
  assert.equal(violations[0].snippet, 'class="btn-primary"');
  assert.equal(violations[1].snippet, 'class="btn-secondary foo"');
});

test('findBtnVariantWithoutBase ignores non-variant classes', () => {
  const text = `<button class="btn foo">OK</button>`;
  assert.deepEqual(findBtnVariantWithoutBase(text, 'sample.component.ts'), []);
});
