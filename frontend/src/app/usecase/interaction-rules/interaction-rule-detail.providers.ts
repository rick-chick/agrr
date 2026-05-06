import { Provider } from '@angular/core';
import { InteractionRuleApiGateway } from '../../adapters/interaction-rules/interaction-rule-api.gateway';
import { InteractionRuleDetailPresenter } from '../../adapters/interaction-rules/interaction-rule-detail.presenter';
import { DeleteInteractionRuleUseCase } from './delete-interaction-rule.usecase';
import { DELETE_INTERACTION_RULE_OUTPUT_PORT } from './delete-interaction-rule.output-port';
import { INTERACTION_RULE_GATEWAY } from './interaction-rule-gateway';
import { LOAD_INTERACTION_RULE_DETAIL_OUTPUT_PORT } from './load-interaction-rule-detail.output-port';
import { LoadInteractionRuleDetailUseCase } from './load-interaction-rule-detail.usecase';

export const INTERACTION_RULE_DETAIL_PROVIDERS: readonly Provider[] = [
  InteractionRuleDetailPresenter,
  LoadInteractionRuleDetailUseCase,
  DeleteInteractionRuleUseCase,
  { provide: LOAD_INTERACTION_RULE_DETAIL_OUTPUT_PORT, useExisting: InteractionRuleDetailPresenter },
  { provide: DELETE_INTERACTION_RULE_OUTPUT_PORT, useExisting: InteractionRuleDetailPresenter },
  { provide: INTERACTION_RULE_GATEWAY, useClass: InteractionRuleApiGateway }
];

export { InteractionRuleDetailPresenter } from '../../adapters/interaction-rules/interaction-rule-detail.presenter';
