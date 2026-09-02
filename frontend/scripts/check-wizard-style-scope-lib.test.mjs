import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { findWizardStyleScopeViolations } from './check-wizard-style-scope-lib.mjs';

describe('findWizardStyleScopeViolations', () => {
  it('flags inline compact-progress in page templates', () => {
    const violations = findWizardStyleScopeViolations({
      'src/app/components/public-plans/public-plan-create.component.ts':
        '<div class="compact-progress">',
    });
    assert.equal(violations.length, 1);
    assert.match(violations[0].message, /forbidden/);
  });

  it('allows compact-progress in wizard-progress pattern', () => {
    const violations = findWizardStyleScopeViolations({
      'src/app/components/shared/patterns/wizard-progress.pattern.ts':
        '<div class="compact-progress">',
    });
    assert.equal(violations.length, 0);
  });
});
