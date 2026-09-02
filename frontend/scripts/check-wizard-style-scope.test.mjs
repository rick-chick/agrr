import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  checkWizardStyleScopeFiles,
  findWizardInlineProgressViolations,
  findWizardProgressStyleScopeViolations,
  isDedicatedWizardProgressComponent,
} from './check-wizard-style-scope-lib.mjs';

test('UI-R3 flags inline compact-progress in page templates', () => {
  const content = `
    <div class="compact-header-card">
      <div class="compact-progress">
        <div class="compact-step active"></div>
      </div>
    </div>`;
  const v = findWizardInlineProgressViolations(content, 'public-plan-create.component.ts');
  assert.equal(v.some((x) => x.id === 'UI-R3-wizard-inline-progress'), true);
});

test('UI-R3 allows compact-progress in dedicated wizard progress component', () => {
  const content = `<div class="compact-progress"></div>`;
  const file = 'src/app/components/entry-schedule/entry-schedule-wizard-progress.component.ts';
  assert.equal(isDedicatedWizardProgressComponent(file), true);
  assert.equal(findWizardInlineProgressViolations(content, file).length, 0);
});

test('UI-R5 requires public-plan.component.css on dedicated wizard progress components', () => {
  const file = 'src/app/components/entry-schedule/entry-schedule-wizard-progress.component.ts';
  const missing = findWizardProgressStyleScopeViolations(
    `@Component({ template: '<div class="compact-progress"></div>' })`,
    file,
  );
  assert.equal(missing.some((x) => x.id === 'UI-R5-wizard-progress-shared-styles'), true);

  const ok = findWizardProgressStyleScopeViolations(
    `@Component({ styleUrls: ['../public-plans/public-plan.component.css'], template: '' })`,
    file,
  );
  assert.equal(ok.length, 0);
});

test('checkWizardStyleScopeFiles aggregates by file', () => {
  const result = checkWizardStyleScopeFiles({
    'public-plan-create.component.ts': '<div class="compact-progress"></div>',
  });
  assert.equal(result.length, 1);
  assert.equal(result[0].file, 'public-plan-create.component.ts');
  assert.equal(result[0].id, 'UI-R3-wizard-inline-progress');
});
