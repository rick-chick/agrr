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

  it('maps every known API validation message to a dedicated i18n key', () => {
    const knownMessages: Array<{ message: string; key: string }> = [
      { message: 'must contain at least one stage', key: 'must_contain_one_stage' },
      { message: 'must be an object', key: 'must_be_object' },
      { message: 'must be greater than 0', key: 'must_be_positive' },
      { message: 'duplicate stage order in proposal', key: 'duplicate_stage_order' },
      { message: 'cannot be blank', key: 'cannot_be_blank' },
      { message: 'duplicate ref in proposal', key: 'duplicate_ref' },
      { message: 'must be one of jp, us, in', key: 'invalid_region' },
      {
        message: 'must be field_work, basal_fertilization, or topdress_fertilization',
        key: 'invalid_task_type'
      },
      {
        message: 'must reference an agricultural_tasks.ref in the proposal',
        key: 'missing_task_ref'
      },
      { message: 'must match a stages[].order in the proposal', key: 'invalid_stage_order' },
      {
        message: 'duplicate blueprint for the same task, stage, and gdd_trigger',
        key: 'duplicate_blueprint'
      },
      {
        message: 'is required and must be a non-negative number',
        key: 'non_negative_number'
      }
    ];

    for (const { message, key } of knownMessages) {
      expect(
        setupProposalValidationErrorI18nKey({ path: 'x', message })
      ).toBe(`crops.setup_proposal_import.validation_errors.${key}`);
    }
  });
});
