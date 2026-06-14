import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanWorkRecordsPresenter } from '../../adapters/plans/plan-work-records.presenter';
import { WorkRecordApiGateway } from '../../adapters/plans/work-record-api.gateway';
import { LOAD_WORK_RECORDS_OUTPUT_PORT } from './load-work-records.output-port';
import { LoadWorkRecordsUseCase } from './load-work-records.usecase';
import { PLAN_GATEWAY } from './plan-gateway';
import { WORK_RECORD_GATEWAY } from './work-record-gateway';

export const PLAN_WORK_RECORDS_PROVIDERS: readonly Provider[] = [
  PlanWorkRecordsPresenter,
  LoadWorkRecordsUseCase,
  { provide: LOAD_WORK_RECORDS_OUTPUT_PORT, useExisting: PlanWorkRecordsPresenter },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: WORK_RECORD_GATEWAY, useClass: WorkRecordApiGateway }
];

export { PlanWorkRecordsPresenter } from '../../adapters/plans/plan-work-records.presenter';
