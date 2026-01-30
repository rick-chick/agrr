import { InjectionToken } from '@angular/core';
import { InteractionRuleListDataDto } from './load-interaction-rule-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadInteractionRuleListOutputPort {
  present(dto: InteractionRuleListDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_INTERACTION_RULE_LIST_OUTPUT_PORT =
  new InjectionToken<LoadInteractionRuleListOutputPort>(
    'LOAD_INTERACTION_RULE_LIST_OUTPUT_PORT'
  );
