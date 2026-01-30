import { InjectionToken } from '@angular/core';
import { InteractionRuleDetailDataDto } from './load-interaction-rule-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadInteractionRuleDetailOutputPort {
  present(dto: InteractionRuleDetailDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_INTERACTION_RULE_DETAIL_OUTPUT_PORT = new InjectionToken<LoadInteractionRuleDetailOutputPort>(
  'LOAD_INTERACTION_RULE_DETAIL_OUTPUT_PORT'
);