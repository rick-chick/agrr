import { Provider } from '@angular/core';
import { InteractionRuleApiGateway } from '../../adapters/interaction-rules/interaction-rule-api.gateway';
import { InteractionRuleCreatePresenter } from '../../adapters/interaction-rules/interaction-rule-create.presenter';
import { CREATE_INTERACTION_RULE_OUTPUT_PORT } from './create-interaction-rule.output-port';
import { CreateInteractionRuleUseCase } from './create-interaction-rule.usecase';
import { INTERACTION_RULE_GATEWAY } from './interaction-rule-gateway';

export const INTERACTION_RULE_CREATE_PROVIDERS: readonly Provider[] = [
  InteractionRuleCreatePresenter,
  CreateInteractionRuleUseCase,
  { provide: CREATE_INTERACTION_RULE_OUTPUT_PORT, useExisting: InteractionRuleCreatePresenter },
  { provide: INTERACTION_RULE_GATEWAY, useClass: InteractionRuleApiGateway }
];

export { InteractionRuleCreatePresenter } from '../../adapters/interaction-rules/interaction-rule-create.presenter';
