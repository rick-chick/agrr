import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  checkWizardStyleScopeFiles,
  findWizardInlineProgressViolations,
} from './check-wizard-style-scope-lib.mjs';

describe('checkWizardStyleScopeFiles', () => {
  it('flags inline compact-progress in page templates', () => {
    const violations = checkWizardStyleScopeFiles({
      'src/app/components/public-plans/public-plan-create.component.ts':
        '<div class="compact-progress">',
    });
    assert.equal(violations.length, 1);
    assert.equal(violations[0].id, 'UI-R3-wizard-inline-progress');
    assert.match(violations[0].message, /forbidden/);
  });

  it('allows compact-progress in dedicated wizard-progress components', () => {
    const violations = findWizardInlineProgressViolations(
      '<div class="compact-progress">',
      'src/app/components/public-plans/public-plan-wizard-progress.component.ts',
    );
    assert.equal(violations.length, 0);
  });
});
