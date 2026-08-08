import { describe, it, expect } from 'vitest';
import { setupProposalValidationErrorI18nKey } from './setup-proposal-validation-error-i18n';

describe('setupProposalValidationErrorI18nKey', () => {
  it('maps known API messages to i18n keys', () => {
    expect(
      setupProposalValidationErrorI18nKey({
        path: 'stages[0].name',
        message: 'is required'
      })
    ).toBe('crops.setup_proposal_import.validation_errors.is_required');

    expect(
      setupProposalValidationErrorI18nKey({
        path: 'stages[0].order',
        message: 'conflicts with an existing crop stage order'
      })
    ).toBe('crops.setup_proposal_import.validation_errors.stage_order_conflict');
  });

  it('passes through translation keys unchanged', () => {
    expect(
      setupProposalValidationErrorI18nKey({
        path: 'stages',
        message: 'crops.setup_proposal_import.validation_errors.is_required'
      })
    ).toBe('crops.setup_proposal_import.validation_errors.is_required');
  });

  it('falls back to generic for unknown messages', () => {
    expect(
      setupProposalValidationErrorI18nKey({
        path: 'unknown',
        message: 'something unexpected'
      })
    ).toBe('crops.setup_proposal_import.validation_errors.generic');
  });
});
