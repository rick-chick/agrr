import { InjectionToken } from '@angular/core';
import { DeleteInteractionRuleSuccessDto } from './delete-interaction-rule.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeleteInteractionRuleOutputPort {
  onSuccess(dto: DeleteInteractionRuleSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_INTERACTION_RULE_OUTPUT_PORT = new InjectionToken<DeleteInteractionRuleOutputPort>(
  'DELETE_INTERACTION_RULE_OUTPUT_PORT'
);