import { Provider } from '@angular/core';
import { ApiService } from '../../services/api.service';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { PublicPlanApiGateway } from '../../adapters/public-plans/public-plan-api.gateway';
import { PublicPlanCreatePresenter } from '../../adapters/public-plans/public-plan-create.presenter';
import { LOAD_PUBLIC_PLAN_FARMS_OUTPUT_PORT } from './load-public-plan-farms.output-port';
import { LoadPublicPlanFarmsUseCase } from './load-public-plan-farms.usecase';
import { PUBLIC_PLAN_GATEWAY } from './public-plan-gateway';
import { PUBLIC_PLAN_SESSION_PORT } from './public-plan-session.port';
import { RESET_PUBLIC_PLAN_CREATION_STATE_OUTPUT_PORT } from './reset-public-plan-creation-state.output-port';
import { ResetPublicPlanCreationStateUseCase } from './reset-public-plan-creation-state.usecase';

export const PUBLIC_PLAN_CREATE_PROVIDERS: readonly Provider[] = [
  LoadPublicPlanFarmsUseCase,
  ResetPublicPlanCreationStateUseCase,
  PublicPlanCreatePresenter,
  { provide: LOAD_PUBLIC_PLAN_FARMS_OUTPUT_PORT, useExisting: PublicPlanCreatePresenter },
  { provide: RESET_PUBLIC_PLAN_CREATION_STATE_OUTPUT_PORT, useValue: {} },
  { provide: PUBLIC_PLAN_SESSION_PORT, useExisting: PublicPlanStore },
  { provide: PUBLIC_PLAN_GATEWAY, useClass: PublicPlanApiGateway },
  ApiService
];

export { PublicPlanCreatePresenter } from '../../adapters/public-plans/public-plan-create.presenter';
