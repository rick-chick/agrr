import { InjectionToken } from '@angular/core';
import { UpdateInteractionRuleSuccessDto } from './update-interaction-rule.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateInteractionRuleOutputPort {
  present(dto: UpdateInteractionRuleSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_INTERACTION_RULE_OUTPUT_PORT = new InjectionToken<UpdateInteractionRuleOutputPort>(
  'UPDATE_INTERACTION_RULE_OUTPUT_PORT'
);