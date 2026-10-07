import { Inject, Injectable } from '@angular/core';
import { LoadInteractionRuleListInputPort } from './load-interaction-rule-list.input-port';
import {
  LoadInteractionRuleListOutputPort,
  LOAD_INTERACTION_RULE_LIST_OUTPUT_PORT
} from './load-interaction-rule-list.output-port';
import {
  INTERACTION_RULE_GATEWAY,
  InteractionRuleGateway
} from './interaction-rule-gateway';

@Injectable()
export class LoadInteractionRuleListUseCase implements LoadInteractionRuleListInputPort {
  constructor(
    @Inject(LOAD_INTERACTION_RULE_LIST_OUTPUT_PORT)
    private readonly outputPort: LoadInteractionRuleListOutputPort,
    @Inject(INTERACTION_RULE_GATEWAY)
    private readonly interactionRuleGateway: InteractionRuleGateway
  ) {}

  execute(): void {
    this.interactionRuleGateway.list().subscribe({
      next: (rules) => this.outputPort.present({ rules }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
