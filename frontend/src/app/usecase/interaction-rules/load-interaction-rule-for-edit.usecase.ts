import { Inject, Injectable } from '@angular/core';
import { LoadInteractionRuleForEditInputPort } from './load-interaction-rule-for-edit.input-port';
import { LoadInteractionRuleForEditOutputPort, LOAD_INTERACTION_RULE_FOR_EDIT_OUTPUT_PORT } from './load-interaction-rule-for-edit.output-port';
import { INTERACTION_RULE_GATEWAY, InteractionRuleGateway } from './interaction-rule-gateway';
import { LoadInteractionRuleForEditInputDto } from './load-interaction-rule-for-edit.dtos';

@Injectable()
export class LoadInteractionRuleForEditUseCase implements LoadInteractionRuleForEditInputPort {
  constructor(
    @Inject(LOAD_INTERACTION_RULE_FOR_EDIT_OUTPUT_PORT) private readonly outputPort: LoadInteractionRuleForEditOutputPort,
    @Inject(INTERACTION_RULE_GATEWAY) private readonly interactionRuleGateway: InteractionRuleGateway
  ) {}

  execute(dto: LoadInteractionRuleForEditInputDto): void {
    this.interactionRuleGateway.show(dto.interactionRuleId).subscribe({
      next: (interactionRule) => this.outputPort.present({ interactionRule }),
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}