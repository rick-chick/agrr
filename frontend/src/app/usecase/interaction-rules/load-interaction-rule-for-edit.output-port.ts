import { InjectionToken } from '@angular/core';
import { LoadInteractionRuleForEditDataDto } from './load-interaction-rule-for-edit.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadInteractionRuleForEditOutputPort {
  present(dto: LoadInteractionRuleForEditDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_INTERACTION_RULE_FOR_EDIT_OUTPUT_PORT = new InjectionToken<LoadInteractionRuleForEditOutputPort>(
  'LOAD_INTERACTION_RULE_FOR_EDIT_OUTPUT_PORT'
);