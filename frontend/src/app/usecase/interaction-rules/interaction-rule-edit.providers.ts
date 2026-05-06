import { Provider } from '@angular/core';
import { InteractionRuleApiGateway } from '../../adapters/interaction-rules/interaction-rule-api.gateway';
import { InteractionRuleEditPresenter } from '../../adapters/interaction-rules/interaction-rule-edit.presenter';
import { INTERACTION_RULE_GATEWAY } from './interaction-rule-gateway';
import { LOAD_INTERACTION_RULE_FOR_EDIT_OUTPUT_PORT } from './load-interaction-rule-for-edit.output-port';
import { LoadInteractionRuleForEditUseCase } from './load-interaction-rule-for-edit.usecase';
import { UPDATE_INTERACTION_RULE_OUTPUT_PORT } from './update-interaction-rule.output-port';
import { UpdateInteractionRuleUseCase } from './update-interaction-rule.usecase';

export const INTERACTION_RULE_EDIT_PROVIDERS: readonly Provider[] = [
  InteractionRuleEditPresenter,
  LoadInteractionRuleForEditUseCase,
  UpdateInteractionRuleUseCase,
  { provide: LOAD_INTERACTION_RULE_FOR_EDIT_OUTPUT_PORT, useExisting: InteractionRuleEditPresenter },
  { provide: UPDATE_INTERACTION_RULE_OUTPUT_PORT, useExisting: InteractionRuleEditPresenter },
  { provide: INTERACTION_RULE_GATEWAY, useClass: InteractionRuleApiGateway }
];

export { InteractionRuleEditPresenter } from '../../adapters/interaction-rules/interaction-rule-edit.presenter';
