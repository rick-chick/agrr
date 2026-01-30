import { DeleteInteractionRuleInputDto } from './delete-interaction-rule.dtos';

export interface DeleteInteractionRuleInputPort {
  execute(dto: DeleteInteractionRuleInputDto): void;
}