import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  checkUiCompositionFiles,
  findLinkInlineViolations,
  findUiCompositionViolations,
} from './check-ui-composition-lib.mjs';

test('R1 flags page-intro inside compact-header-card', () => {
  const content = `
    <div class="compact-header-card">
      <p class="page-intro muted">desc</p>
    </div>`;
  const v = findUiCompositionViolations(content);
  assert.equal(v.some((x) => x.id === 'R1-page-intro-in-compact-header'), true);
});

test('R1 does not flag separated description', () => {
  const content = `
    <app-funnel-shell descriptionKey="pages.entry_schedule.description"></app-funnel-shell>`;
  const v = findUiCompositionViolations(content);
  assert.equal(v.length, 0);
});

test('R2 flags link-inline used without global definition', () => {
  const v = findLinkInlineViolations(['<a class="link-inline">x</a>'], '/* empty */');
  assert.equal(v.some((x) => x.id === 'R2-link-inline-undefined'), true);
});

test('R2 passes when link-inline is defined and used', () => {
  const v = findLinkInlineViolations(
    ['<a class="link-inline">x</a>'],
    '.link-inline { color: red; }',
  );
  assert.equal(v.length, 0);
});

test('R2 warns when link-inline is defined but unused', () => {
  const v = findLinkInlineViolations(['<a class="btn">x</a>'], '.link-inline { color: red; }');
  assert.equal(v.some((x) => x.id === 'R2-link-inline-unused'), true);
});

test('checkUiCompositionFiles aggregates by file', () => {
  const result = checkUiCompositionFiles(
    {
      'a.ts': '<div class="compact-header-card"><p class="page-intro"></p></div>',
    },
    '',
  );
  assert.equal(result.length, 1);
  assert.equal(result[0].file, 'a.ts');
});
