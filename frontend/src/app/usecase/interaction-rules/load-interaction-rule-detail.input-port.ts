import { LoadInteractionRuleDetailInputDto } from './load-interaction-rule-detail.dtos';

export interface LoadInteractionRuleDetailInputPort {
  execute(dto: LoadInteractionRuleDetailInputDto): void;
}