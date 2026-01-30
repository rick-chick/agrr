import { Inject, Injectable } from '@angular/core';
import { LoadInteractionRuleDetailInputPort } from './load-interaction-rule-detail.input-port';
import { LoadInteractionRuleDetailOutputPort, LOAD_INTERACTION_RULE_DETAIL_OUTPUT_PORT } from './load-interaction-rule-detail.output-port';
import { INTERACTION_RULE_GATEWAY, InteractionRuleGateway } from './interaction-rule-gateway';
import { LoadInteractionRuleDetailInputDto } from './load-interaction-rule-detail.dtos';

@Injectable()
export class LoadInteractionRuleDetailUseCase implements LoadInteractionRuleDetailInputPort {
  constructor(
    @Inject(LOAD_INTERACTION_RULE_DETAIL_OUTPUT_PORT) private readonly outputPort: LoadInteractionRuleDetailOutputPort,
    @Inject(INTERACTION_RULE_GATEWAY) private readonly interactionRuleGateway: InteractionRuleGateway
  ) {}

  execute(dto: LoadInteractionRuleDetailInputDto): void {
    this.interactionRuleGateway.show(dto.interactionRuleId).subscribe({
      next: (rule) => this.outputPort.present({ rule }),
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}