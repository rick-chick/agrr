import { Inject, Injectable } from '@angular/core';
import { UpdateInteractionRuleInputPort } from './update-interaction-rule.input-port';
import { UpdateInteractionRuleOutputPort, UPDATE_INTERACTION_RULE_OUTPUT_PORT } from './update-interaction-rule.output-port';
import { INTERACTION_RULE_GATEWAY, InteractionRuleGateway } from './interaction-rule-gateway';
import { UpdateInteractionRuleInputDto } from './update-interaction-rule.dtos';

@Injectable()
export class UpdateInteractionRuleUseCase implements UpdateInteractionRuleInputPort {
  constructor(
    @Inject(UPDATE_INTERACTION_RULE_OUTPUT_PORT) private readonly outputPort: UpdateInteractionRuleOutputPort,
    @Inject(INTERACTION_RULE_GATEWAY) private readonly interactionRuleGateway: InteractionRuleGateway
  ) {}

  execute(dto: UpdateInteractionRuleInputDto): void {
    const payload = {
      rule_type: dto.rule_type,
      source_group: dto.source_group,
      target_group: dto.target_group,
      impact_ratio: dto.impact_ratio,
      is_directional: dto.is_directional,
      description: dto.description,
      region: dto.region
    };

    this.interactionRuleGateway.update(dto.interactionRuleId, payload).subscribe({
      next: (interactionRule) => {
        this.outputPort.present({ interactionRule });
        dto.onSuccess?.(interactionRule);
      },
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}