import { InteractionRule } from '../../domain/interaction-rules/interaction-rule';

export interface CreateInteractionRuleInputDto {
  rule_type: string;
  source_group: string;
  target_group: string;
  impact_ratio: number;
  is_directional: boolean;
  description: string | null;
  region: string | null;
  onSuccess?: (interactionRule: InteractionRule) => void;
}

export interface CreateInteractionRuleSuccessDto {
  interactionRule: InteractionRule;
}