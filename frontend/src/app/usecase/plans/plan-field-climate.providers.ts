import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { WorkRecordApiGateway } from '../../adapters/plans/work-record-api.gateway';
import { DemoFieldClimateGateway } from '../../adapters/plans/demo-field-climate.gateway';
import { FieldClimateApiGateway } from '../../adapters/plans/field-climate-api.gateway';
import { PlanFieldClimatePresenter } from '../../adapters/plans/plan-field-climate.presenter';
import { FIELD_CLIMATE_GATEWAY } from './field-climate/field-climate.gateway';
import { LOAD_FIELD_CLIMATE_OUTPUT_PORT } from './field-climate/load-field-climate.output-port';
import { LoadFieldClimateUseCase } from './field-climate/load-field-climate.usecase';
import { PLAN_GATEWAY } from './plan-gateway';
import { WORK_RECORD_GATEWAY } from './work-record-gateway';

export const PLAN_FIELD_CLIMATE_SHARED_PROVIDERS: readonly Provider[] = [
  PlanFieldClimatePresenter,
  LoadFieldClimateUseCase,
  { provide: LOAD_FIELD_CLIMATE_OUTPUT_PORT, useExisting: PlanFieldClimatePresenter }
];

export const PLAN_FIELD_CLIMATE_API_PROVIDERS: readonly Provider[] = [
  ...PLAN_FIELD_CLIMATE_SHARED_PROVIDERS,
  FieldClimateApiGateway,
  WorkRecordApiGateway,
  PlanApiGateway,
  { provide: FIELD_CLIMATE_GATEWAY, useExisting: FieldClimateApiGateway },
  { provide: WORK_RECORD_GATEWAY, useExisting: WorkRecordApiGateway },
  { provide: PLAN_GATEWAY, useExisting: PlanApiGateway }
];

export const PLAN_FIELD_CLIMATE_DEMO_PROVIDERS: readonly Provider[] = [
  ...PLAN_FIELD_CLIMATE_SHARED_PROVIDERS,
  DemoFieldClimateGateway,
  { provide: FIELD_CLIMATE_GATEWAY, useExisting: DemoFieldClimateGateway }
];
