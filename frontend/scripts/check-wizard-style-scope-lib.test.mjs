import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import {
  findWizardStyleScopeViolations,
  shouldScanWizardStyleScope,
} from './check-wizard-style-scope-lib.mjs';

describe('check-wizard-style-scope-lib', () => {
  it('flags inline compact-progress in public-plan page components', () => {
    const violations = findWizardStyleScopeViolations(
      `template: \`
        <div class="compact-progress">
      \``,
      'src/app/components/public-plans/public-plan-create.component.ts',
    );
    assert.equal(violations.length, 1);
  });

  it('allows wizard-progress pattern file', () => {
    assert.equal(
      shouldScanWizardStyleScope('src/app/components/shared/patterns/wizard-progress.pattern.ts'),
      false,
    );
  });

  it('allows funnel shell usage without inline markup', () => {
    const violations = findWizardStyleScopeViolations(
      `<app-wizard-progress [steps]="wizardSteps" />`,
      'src/app/components/public-plans/public-plan-create.component.ts',
    );
    assert.equal(violations.length, 0);
  });
});
