import { Provider } from '@angular/core';
import { FieldClimateApiGateway } from '../../adapters/plans/field-climate-api.gateway';
import { PlanFieldClimatePresenter } from '../../adapters/plans/plan-field-climate.presenter';
import { FIELD_CLIMATE_GATEWAY } from './field-climate/field-climate.gateway';
import { LOAD_FIELD_CLIMATE_OUTPUT_PORT } from './field-climate/load-field-climate.output-port';
import { LoadFieldClimateUseCase } from './field-climate/load-field-climate.usecase';

export const PLAN_FIELD_CLIMATE_PROVIDERS: readonly Provider[] = [
  PlanFieldClimatePresenter,
  LoadFieldClimateUseCase,
  FieldClimateApiGateway,
  { provide: LOAD_FIELD_CLIMATE_OUTPUT_PORT, useExisting: PlanFieldClimatePresenter },
  { provide: FIELD_CLIMATE_GATEWAY, useExisting: FieldClimateApiGateway }
];

export { PlanFieldClimatePresenter } from '../../adapters/plans/plan-field-climate.presenter';
export { FieldClimateApiGateway } from '../../adapters/plans/field-climate-api.gateway';
