import { Provider } from '@angular/core';
import { DemoFieldClimateGateway } from '../../adapters/plans/demo-field-climate.gateway';
import { FieldClimateApiGateway } from '../../adapters/plans/field-climate-api.gateway';
import { PlanFieldClimatePresenter } from '../../adapters/plans/plan-field-climate.presenter';
import { FIELD_CLIMATE_GATEWAY } from './field-climate/field-climate.gateway';
import { LOAD_FIELD_CLIMATE_OUTPUT_PORT } from './field-climate/load-field-climate.output-port';
import { LoadFieldClimateUseCase } from './field-climate/load-field-climate.usecase';

export const PLAN_FIELD_CLIMATE_SHARED_PROVIDERS: readonly Provider[] = [
  PlanFieldClimatePresenter,
  LoadFieldClimateUseCase,
  { provide: LOAD_FIELD_CLIMATE_OUTPUT_PORT, useExisting: PlanFieldClimatePresenter }
];

export const PLAN_FIELD_CLIMATE_API_PROVIDERS: readonly Provider[] = [
  ...PLAN_FIELD_CLIMATE_SHARED_PROVIDERS,
  FieldClimateApiGateway,
  { provide: FIELD_CLIMATE_GATEWAY, useExisting: FieldClimateApiGateway }
];

export const PLAN_FIELD_CLIMATE_DEMO_PROVIDERS: readonly Provider[] = [
  ...PLAN_FIELD_CLIMATE_SHARED_PROVIDERS,
  DemoFieldClimateGateway,
  { provide: FIELD_CLIMATE_GATEWAY, useExisting: DemoFieldClimateGateway }
];