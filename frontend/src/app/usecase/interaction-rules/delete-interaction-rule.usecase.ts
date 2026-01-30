import { Inject, Injectable } from '@angular/core';
import { DeleteInteractionRuleInputPort } from './delete-interaction-rule.input-port';
import { DeleteInteractionRuleOutputPort, DELETE_INTERACTION_RULE_OUTPUT_PORT } from './delete-interaction-rule.output-port';
import { INTERACTION_RULE_GATEWAY, InteractionRuleGateway } from './interaction-rule-gateway';
import { DeleteInteractionRuleInputDto } from './delete-interaction-rule.dtos';

@Injectable()
export class DeleteInteractionRuleUseCase implements DeleteInteractionRuleInputPort {
  constructor(
    @Inject(DELETE_INTERACTION_RULE_OUTPUT_PORT) private readonly outputPort: DeleteInteractionRuleOutputPort,
    @Inject(INTERACTION_RULE_GATEWAY) private readonly interactionRuleGateway: InteractionRuleGateway
  ) {}

  execute(dto: DeleteInteractionRuleInputDto): void {
    this.interactionRuleGateway.destroy(dto.interactionRuleId).subscribe({
      next: (response) => {
        this.outputPort.onSuccess({
          deletedInteractionRuleId: dto.interactionRuleId,
          undo: response,
          refresh: dto.onAfterUndo
        });
        dto.onSuccess?.();
      },
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}