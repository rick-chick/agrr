import { Inject, Injectable } from '@angular/core';
import { CreateInteractionRuleInputPort } from './create-interaction-rule.input-port';
import { CreateInteractionRuleOutputPort, CREATE_INTERACTION_RULE_OUTPUT_PORT } from './create-interaction-rule.output-port';
import { INTERACTION_RULE_GATEWAY, InteractionRuleGateway } from './interaction-rule-gateway';
import { CreateInteractionRuleInputDto } from './create-interaction-rule.dtos';

@Injectable()
export class CreateInteractionRuleUseCase implements CreateInteractionRuleInputPort {
  constructor(
    @Inject(CREATE_INTERACTION_RULE_OUTPUT_PORT) private readonly outputPort: CreateInteractionRuleOutputPort,
    @Inject(INTERACTION_RULE_GATEWAY) private readonly interactionRuleGateway: InteractionRuleGateway
  ) {}

  execute(dto: CreateInteractionRuleInputDto): void {
    const payload = {
      rule_type: dto.rule_type,
      source_group: dto.source_group,
      target_group: dto.target_group,
      impact_ratio: dto.impact_ratio,
      is_directional: dto.is_directional,
      description: dto.description,
      region: dto.region
    };

    this.interactionRuleGateway.create(payload).subscribe({
      next: (interactionRule) => {
        this.outputPort.present({ interactionRule });
        dto.onSuccess?.(interactionRule);
      },
      error: (err) =>
        this.outputPort.onError({
          message: err.error?.errors?.join(', ') ?? err.error?.error ?? err?.message ?? 'Unknown error'
        })
    });
  }
}