import { CropSetupProposalValidationErrorItem } from '../domain/crops/crop-setup-proposal';
import { isTranslationKey } from './error-dto-i18n-key';

const MESSAGE_TO_KEY: Record<string, string> = {
  'is required': 'crops.setup_proposal_import.validation_errors.is_required',
  'must contain at least one stage':
    'crops.setup_proposal_import.validation_errors.must_contain_one_stage',
  'must be an object': 'crops.setup_proposal_import.validation_errors.must_be_object',
  'must be greater than 0': 'crops.setup_proposal_import.validation_errors.must_be_positive',
  'duplicate stage order in proposal':
    'crops.setup_proposal_import.validation_errors.duplicate_stage_order',
  'conflicts with an existing crop stage order':
    'crops.setup_proposal_import.validation_errors.stage_order_conflict',
  'cannot be blank': 'crops.setup_proposal_import.validation_errors.cannot_be_blank',
  'duplicate ref in proposal': 'crops.setup_proposal_import.validation_errors.duplicate_ref',
  'must be one of jp, us, in': 'crops.setup_proposal_import.validation_errors.invalid_region',
  'must be field_work, basal_fertilization, or topdress_fertilization':
    'crops.setup_proposal_import.validation_errors.invalid_task_type',
  'must reference an agricultural_tasks.ref in the proposal':
    'crops.setup_proposal_import.validation_errors.missing_task_ref',
  'must match a stages[].order in the proposal':
    'crops.setup_proposal_import.validation_errors.invalid_stage_order',
  'duplicate blueprint for the same task, stage, and gdd_trigger':
    'crops.setup_proposal_import.validation_errors.duplicate_blueprint',
  'is required and must be a non-negative number':
    'crops.setup_proposal_import.validation_errors.non_negative_number'
};

/**
 * Maps API validation error messages to ngx-translate keys.
 * Falls back to a generic key when the server message is unknown.
 */
export function setupProposalValidationErrorI18nKey(
  item: CropSetupProposalValidationErrorItem
): string {
  if (isTranslationKey(item.message)) {
    return item.message;
  }
  return MESSAGE_TO_KEY[item.message] ?? 'crops.setup_proposal_import.validation_errors.generic';
}
