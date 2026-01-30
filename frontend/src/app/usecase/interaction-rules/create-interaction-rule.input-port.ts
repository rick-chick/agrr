import { CreateInteractionRuleInputDto } from './create-interaction-rule.dtos';

export interface CreateInteractionRuleInputPort {
  execute(dto: CreateInteractionRuleInputDto): void;
}