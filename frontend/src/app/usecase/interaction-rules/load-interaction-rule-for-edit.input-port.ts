import { LoadInteractionRuleForEditInputDto } from './load-interaction-rule-for-edit.dtos';

export interface LoadInteractionRuleForEditInputPort {
  execute(dto: LoadInteractionRuleForEditInputDto): void;
}