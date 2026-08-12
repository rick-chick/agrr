import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanWorkRecordsPresenter } from '../../adapters/plans/plan-work-records.presenter';
import { WorkRecordApiGateway } from '../../adapters/plans/work-record-api.gateway';
import { LOAD_WORK_RECORDS_OUTPUT_PORT } from './load-work-records.output-port';
import { LoadWorkRecordsUseCase } from './load-work-records.usecase';
import { LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT } from './load-plan-vs-actual-summary.output-port';
import { LoadPlanVsActualSummaryUseCase } from './load-plan-vs-actual-summary.usecase';
import { PLAN_GATEWAY } from './plan-gateway';
import { WORK_RECORD_GATEWAY } from './work-record-gateway';

export const PLAN_WORK_RECORDS_PROVIDERS: readonly Provider[] = [
  PlanWorkRecordsPresenter,
  LoadWorkRecordsUseCase,
  LoadPlanVsActualSummaryUseCase,
  { provide: LOAD_WORK_RECORDS_OUTPUT_PORT, useExisting: PlanWorkRecordsPresenter },
  {
    provide: LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT,
    useFactory: (presenter: PlanWorkRecordsPresenter) => ({
      present: (dto: Parameters<PlanWorkRecordsPresenter['presentSaveImpactSummary']>[0]) =>
        presenter.presentSaveImpactSummary(dto),
      onError: (dto: Parameters<PlanWorkRecordsPresenter['onSaveImpactError']>[0]) =>
        presenter.onSaveImpactError(dto)
    }),
    deps: [PlanWorkRecordsPresenter]
  },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: WORK_RECORD_GATEWAY, useClass: WorkRecordApiGateway }
];

export { PlanWorkRecordsPresenter } from '../../adapters/plans/plan-work-records.presenter';
