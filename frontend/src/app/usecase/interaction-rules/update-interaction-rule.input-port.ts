import { UpdateInteractionRuleInputDto } from './update-interaction-rule.dtos';

export interface UpdateInteractionRuleInputPort {
  execute(dto: UpdateInteractionRuleInputDto): void;
}