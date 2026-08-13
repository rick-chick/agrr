import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanLearnPresenter } from '../../adapters/plans/plan-learn.presenter';
import { CROP_GATEWAY } from '../crops/crop-gateway';
import { LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT } from './load-plan-task-schedule.output-port';
import { LoadPlanTaskScheduleUseCase } from './load-plan-task-schedule.usecase';
import { LoadPlanVsActualSummaryUseCase } from './load-plan-vs-actual-summary.usecase';
import { LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT } from './load-plan-vs-actual-summary.output-port';
import { LoadStageGddCalibrationProposalsUseCase } from './load-stage-gdd-calibration-proposals.usecase';
import { LOAD_STAGE_GDD_CALIBRATION_PROPOSALS_OUTPUT_PORT } from './load-stage-gdd-calibration-proposals.output-port';
import { PLAN_GATEWAY } from './plan-gateway';

export const PLAN_LEARN_PROVIDERS: readonly Provider[] = [
  PlanLearnPresenter,
  LoadPlanTaskScheduleUseCase,
  LoadPlanVsActualSummaryUseCase,
  LoadStageGddCalibrationProposalsUseCase,
  { provide: LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT, useExisting: PlanLearnPresenter },
  {
    provide: LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT,
    useFactory: (
      presenter: PlanLearnPresenter,
      proposalsUseCase: LoadStageGddCalibrationProposalsUseCase
    ) => ({
      present: (dto: Parameters<PlanLearnPresenter['presentVarianceSummary']>[0]) => {
        presenter.presentVarianceSummary(dto);
        const rawProposals = dto.summary.stage_gdd_calibration_proposals ?? [];
        if (rawProposals.length > 0) {
          const loadGeneration = presenter.beginStageGddProposalsLoad();
          proposalsUseCase.execute({ rawProposals, loadGeneration });
        }
      },
      onError: (dto: Parameters<PlanLearnPresenter['onVarianceError']>[0]) =>
        presenter.onVarianceError(dto)
    }),
    deps: [PlanLearnPresenter, LoadStageGddCalibrationProposalsUseCase]
  },
  {
    provide: LOAD_STAGE_GDD_CALIBRATION_PROPOSALS_OUTPUT_PORT,
    useExisting: PlanLearnPresenter
  },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: CROP_GATEWAY, useClass: CropApiGateway }
];

export { PlanLearnPresenter } from '../../adapters/plans/plan-learn.presenter';
