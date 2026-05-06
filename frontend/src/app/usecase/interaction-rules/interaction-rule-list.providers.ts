import { Provider } from '@angular/core';
import { InteractionRuleApiGateway } from '../../adapters/interaction-rules/interaction-rule-api.gateway';
import { InteractionRuleListPresenter } from '../../adapters/interaction-rules/interaction-rule-list.presenter';
import { DeleteInteractionRuleUseCase } from './delete-interaction-rule.usecase';
import { DELETE_INTERACTION_RULE_OUTPUT_PORT } from './delete-interaction-rule.output-port';
import { INTERACTION_RULE_GATEWAY } from './interaction-rule-gateway';
import { LOAD_INTERACTION_RULE_LIST_OUTPUT_PORT } from './load-interaction-rule-list.output-port';
import { LoadInteractionRuleListUseCase } from './load-interaction-rule-list.usecase';

export const INTERACTION_RULE_LIST_PROVIDERS: readonly Provider[] = [
  InteractionRuleListPresenter,
  LoadInteractionRuleListUseCase,
  DeleteInteractionRuleUseCase,
  {
    provide: LOAD_INTERACTION_RULE_LIST_OUTPUT_PORT,
    useExisting: InteractionRuleListPresenter
  },
  {
    provide: DELETE_INTERACTION_RULE_OUTPUT_PORT,
    useExisting: InteractionRuleListPresenter
  },
  { provide: INTERACTION_RULE_GATEWAY, useClass: InteractionRuleApiGateway }
];

export { InteractionRuleListPresenter } from '../../adapters/interaction-rules/interaction-rule-list.presenter';
