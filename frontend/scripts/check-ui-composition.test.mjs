import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  checkUiCompositionFiles,
  findLinkInlineViolations,
  findUiCompositionViolations,
  findWizardShellProgressViolations,
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

test('UI-R4 flags FunnelShell wizard variant without wizard progress projection', () => {
  const content = `
    <app-funnel-shell variant="wizard" titleKey="entrySchedule.title">
      <section class="content-card"></section>
    </app-funnel-shell>`;
  const v = findWizardShellProgressViolations(content);
  assert.equal(v.some((x) => x.id === 'UI-R4-wizard-shell-progress'), true);
});

test('UI-R4 passes when wizard progress component is projected', () => {
  const content = `
    <app-funnel-shell variant="wizard" titleKey="entrySchedule.title">
      <app-entry-schedule-wizard-progress activeStep="farm" />
    </app-funnel-shell>`;
  const v = findWizardShellProgressViolations(content);
  assert.equal(v.length, 0);
});

test('UI-R4 passes for hub variant without wizard progress', () => {
  const content = `
    <app-funnel-shell variant="hub" titleKey="entrySchedule.title">
      <section class="content-card"></section>
    </app-funnel-shell>`;
  const v = findWizardShellProgressViolations(content);
  assert.equal(v.length, 0);
});
