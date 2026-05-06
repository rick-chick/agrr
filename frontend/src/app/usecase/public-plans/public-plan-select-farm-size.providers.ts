import { Provider } from '@angular/core';
import { PublicPlanApiGateway } from '../../adapters/public-plans/public-plan-api.gateway';
import { PUBLIC_PLAN_GATEWAY } from './public-plan-gateway';

export const PUBLIC_PLAN_SELECT_FARM_SIZE_PROVIDERS: readonly Provider[] = [
  { provide: PUBLIC_PLAN_GATEWAY, useClass: PublicPlanApiGateway }
];
