import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  auditFluidTypographyTokens,
  findNonFluidTokens,
  findTokenDefinition,
  isFluidClampValue,
} from './check-fluid-typography-tokens-lib.mjs';

test('isFluidClampValue requires clamp()', () => {
  assert.equal(isFluidClampValue('clamp(1rem, 1rem + 0.5vw, 1.25rem)'), true);
  assert.equal(isFluidClampValue('var(--font-size-lg)'), false);
});

test('findTokenDefinition extracts token value from styles.css line', () => {
  const css = `
    :root {
      --font-size-lg: clamp(1rem, 0.95rem + 0.25vw, 1.125rem);
      --font-size-base: 16px;
    }
  `;
  assert.equal(
    findTokenDefinition(css, '--font-size-lg'),
    'clamp(1rem, 0.95rem + 0.25vw, 1.125rem)',
  );
  assert.equal(findTokenDefinition(css, '--font-size-base'), '16px');
});

test('findNonFluidTokens flags fixed px values for lg+ tokens', () => {
  const css = `
    :root {
      --font-size-lg: 18px;
      --font-size-xl: clamp(1.0625rem, 1rem + 0.35vw, 1.25rem);
    }
  `;
  const nonFluid = findNonFluidTokens(css);
  assert.equal(nonFluid.length, 4);
  assert.equal(nonFluid[0].token, '--font-size-lg');
});

test('auditFluidTypographyTokens passes when lg+ tokens use clamp()', async () => {
  const violations = await auditFluidTypographyTokens(
    new URL('..', import.meta.url).pathname,
  );
  assert.deepEqual(violations, []);
});
