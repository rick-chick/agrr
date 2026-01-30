import { InteractionRule } from '../../domain/interaction-rules/interaction-rule';

export interface LoadInteractionRuleDetailInputDto {
  interactionRuleId: number;
}

export interface InteractionRuleDetailDataDto {
  rule: InteractionRule;
}