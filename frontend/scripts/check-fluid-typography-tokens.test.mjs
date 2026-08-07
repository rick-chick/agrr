import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  FLUID_FONT_SIZE_TOKENS,
  auditFluidTypographyFromDisk,
  auditFluidTypographyTokens,
  extractClampMin,
  minExprToPx,
  tokenUsesClamp,
} from './check-fluid-typography-tokens-lib.mjs';

test('tokenUsesClamp detects clamp() on custom property', () => {
  const css = ':root { --font-size-lg: clamp(1rem, 1rem + 0.5vw, 1.125rem); }';
  assert.equal(tokenUsesClamp(css, '--font-size-lg'), true);
  assert.equal(tokenUsesClamp(css, '--font-size-base'), false);
});

test('extractClampMin returns first clamp argument', () => {
  assert.equal(
    extractClampMin('clamp(1rem, calc(1rem + 0.5vw), 1.125rem)'),
    '1rem',
  );
});

test('minExprToPx converts rem and px', () => {
  assert.equal(minExprToPx('1rem'), 16);
  assert.equal(minExprToPx('1.125rem'), 18);
  assert.equal(minExprToPx('18px'), 18);
});

test('auditFluidTypographyTokens flags missing clamp on lg+ tokens', () => {
  const css = `
    :root {
      --font-size-lg: 18px;
      --font-size-xl: clamp(1.125rem, calc(1.125rem + 0.25vw), 1.25rem);
    }
  `;
  const violations = auditFluidTypographyTokens(css);
  assert.ok(violations.some((v) => v.token === '--font-size-lg'));
  assert.ok(violations.some((v) => v.token === '--font-size-2xl'));
});

test('auditFluidTypographyTokens rejects clamp min below 16px', () => {
  const css =
    ':root { --font-size-lg: clamp(0.75rem, 0.5rem + 1vw, 1.125rem); }';
  const violations = auditFluidTypographyTokens(css);
  assert.ok(violations.some((v) => v.rule === 'min-readable'));
});

test('auditFluidTypographyFromDisk passes on styles.css with fluid lg+ tokens', async () => {
  const violations = await auditFluidTypographyFromDisk(
    new URL('..', import.meta.url).pathname,
  );
  assert.deepEqual(
    violations,
    [],
    `violations: ${JSON.stringify(violations, null, 2)}`,
  );
});

test('FLUID_FONT_SIZE_TOKENS includes at least lg and one tier above', () => {
  assert.ok(FLUID_FONT_SIZE_TOKENS.includes('--font-size-lg'));
  assert.ok(FLUID_FONT_SIZE_TOKENS.includes('--font-size-xl'));
  assert.ok(FLUID_FONT_SIZE_TOKENS.length >= 2);
});
