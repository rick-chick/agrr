import { Provider } from '@angular/core';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { PublicPlanApiGateway } from '../../adapters/public-plans/public-plan-api.gateway';
import { PublicPlanSelectCropPresenter } from '../../adapters/public-plans/public-plan-select-crop.presenter';
import { CreatePublicPlanUseCase } from './create-public-plan.usecase';
import { CREATE_PUBLIC_PLAN_OUTPUT_PORT } from './create-public-plan.output-port';
import { LOAD_PUBLIC_PLAN_CROPS_OUTPUT_PORT } from './load-public-plan-crops.output-port';
import { LoadPublicPlanCropsUseCase } from './load-public-plan-crops.usecase';
import { PUBLIC_PLAN_GATEWAY } from './public-plan-gateway';
import { PUBLIC_PLAN_SESSION_PORT } from './public-plan-session.port';
import { RESET_PUBLIC_PLAN_CREATION_STATE_OUTPUT_PORT } from './reset-public-plan-creation-state.output-port';
import { ResetPublicPlanCreationStateUseCase } from './reset-public-plan-creation-state.usecase';

export const PUBLIC_PLAN_SELECT_CROP_PROVIDERS: readonly Provider[] = [
  PublicPlanSelectCropPresenter,
  LoadPublicPlanCropsUseCase,
  CreatePublicPlanUseCase,
  ResetPublicPlanCreationStateUseCase,
  { provide: LOAD_PUBLIC_PLAN_CROPS_OUTPUT_PORT, useExisting: PublicPlanSelectCropPresenter },
  { provide: CREATE_PUBLIC_PLAN_OUTPUT_PORT, useExisting: PublicPlanSelectCropPresenter },
  { provide: RESET_PUBLIC_PLAN_CREATION_STATE_OUTPUT_PORT, useValue: {} },
  { provide: PUBLIC_PLAN_SESSION_PORT, useExisting: PublicPlanStore },
  { provide: PUBLIC_PLAN_GATEWAY, useClass: PublicPlanApiGateway }
];

export { PublicPlanSelectCropPresenter } from '../../adapters/public-plans/public-plan-select-crop.presenter';
