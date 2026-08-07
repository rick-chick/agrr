import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  auditPrimaryColorTokens,
  btnPrimaryUsesColorPrimary,
  countPrimaryDefinitions,
  stylesDefinesBrandTokens,
} from './check-primary-color-tokens-lib.mjs';

test('countPrimaryDefinitions counts only --color-primary declarations', () => {
  const css = `
    :root {
      --color-primary: #2563eb;
      --color-primary-hover: #1d4ed8;
      color: var(--color-primary);
    }
  `;
  assert.equal(countPrimaryDefinitions(css), 1);
});

test('stylesDefinesBrandTokens requires brand primary variants', () => {
  assert.equal(
    stylesDefinesBrandTokens(':root { --color-brand-primary: #2d5016; }'),
    false,
  );
  assert.equal(
    stylesDefinesBrandTokens(`
      :root {
        --color-brand-primary: #2d5016;
        --color-brand-primary-light: #4a7c23;
        --color-brand-primary-dark: #1a3009;
      }
    `),
    true,
  );
});

test('btnPrimaryUsesColorPrimary rejects gradient-primary background', () => {
  const css = `.btn-primary { background: var(--gradient-primary); color: white; }`;
  assert.equal(btnPrimaryUsesColorPrimary(css), false);
});

test('btnPrimaryUsesColorPrimary accepts color-primary background', () => {
  const css = `.btn-primary { background: var(--color-primary); color: var(--color-text-on-primary); }`;
  assert.equal(btnPrimaryUsesColorPrimary(css), true);
});

test('auditPrimaryColorTokens passes on consolidated token layout', async () => {
  const violations = await auditPrimaryColorTokens(
    new URL('..', import.meta.url).pathname,
  );
  assert.deepEqual(violations, []);
});
