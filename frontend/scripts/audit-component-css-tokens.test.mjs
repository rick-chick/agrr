import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  findViolations,
  findViolationsInLine,
  shouldEnforceFail,
  stripVarFallbacks,
} from './audit-component-css-tokens-lib.mjs';

test('findViolationsInLine separates outside var from fallback colors', () => {
  const line = 'color: var(--color-text-muted, #666); background: #fff;';
  const { outside, insideVar } = findViolationsInLine(line, 1);
  assert.equal(outside.length, 1);
  assert.equal(outside[0].value, '#fff');
  assert.equal(insideVar.length, 1);
  assert.equal(insideVar[0].value, '#666');
});

test('shouldEnforceFail fails on outside or fallback violations when enforce', () => {
  assert.equal(shouldEnforceFail(0, 0, true), false);
  assert.equal(shouldEnforceFail(1, 0, true), true);
  assert.equal(shouldEnforceFail(0, 1, true), true);
  assert.equal(shouldEnforceFail(1, 1, false), false);
});

test('stripVarFallbacks removes color and nested rgb fallbacks', () => {
  const input = [
    'color: var(--color-text-muted, #666);',
    'box-shadow: var(--shadow-sm, 0 1px 2px rgb(0 0 0 / 6%));',
  ].join('\n');
  const output = stripVarFallbacks(input);
  assert.equal(output, 'color: var(--color-text-muted);\nbox-shadow: var(--shadow-sm);');
});

test('findViolations flags raw backdrop rgb outside var', () => {
  const css = '.dialog::backdrop { background: rgb(0 0 0 / 0.45); }';
  const { outside, insideVar } = findViolations(css);
  assert.equal(outside.length, 1);
  assert.equal(insideVar.length, 0);
});
