import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import {
  checkWizardStyleScopeFiles,
  findWizardInlineProgressViolations,
  isDedicatedWizardProgressComponent,
} from './check-wizard-style-scope-lib.mjs';

describe('check-wizard-style-scope-lib', () => {
  it('flags inline compact-progress in public-plan page components', () => {
    const violations = findWizardInlineProgressViolations(
      `template: \`
        <div class="compact-progress">
      \``,
      'src/app/components/public-plans/public-plan-create.component.ts',
    );
    assert.equal(violations.length, 1);
    assert.equal(violations[0].id, 'UI-R3-wizard-inline-progress');
  });

  it('allows wizard-progress pattern file', () => {
    assert.equal(
      isDedicatedWizardProgressComponent('src/app/components/shared/patterns/wizard-progress.pattern.ts'),
      true,
    );
  });

  it('allows funnel shell usage without inline markup', () => {
    const violations = checkWizardStyleScopeFiles({
      'src/app/components/public-plans/public-plan-create.component.ts':
        '<app-wizard-progress [steps]="wizardSteps" />',
    });
    assert.equal(violations.length, 0);
  });
});
