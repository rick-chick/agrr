import { InteractionRule } from '../../domain/interaction-rules/interaction-rule';

export interface LoadInteractionRuleForEditInputDto {
  interactionRuleId: number;
}

export interface LoadInteractionRuleForEditDataDto {
  interactionRule: InteractionRule;
}