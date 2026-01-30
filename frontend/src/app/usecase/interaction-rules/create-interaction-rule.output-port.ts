import { InjectionToken } from '@angular/core';
import { CreateInteractionRuleSuccessDto } from './create-interaction-rule.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreateInteractionRuleOutputPort {
  present(dto: CreateInteractionRuleSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_INTERACTION_RULE_OUTPUT_PORT = new InjectionToken<CreateInteractionRuleOutputPort>(
  'CREATE_INTERACTION_RULE_OUTPUT_PORT'
);