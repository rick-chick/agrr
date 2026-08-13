import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanLearnPresenter } from '../../adapters/plans/plan-learn.presenter';
import { CropTaskScheduleBlueprintApiGateway } from '../../adapters/crops/crop-task-schedule-blueprint-api.gateway';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from '../crops/crop-task-schedule-blueprint-gateway';
import { CROP_GATEWAY } from '../crops/crop-gateway';
import { LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT } from './load-plan-task-schedule.output-port';
import { LoadPlanTaskScheduleUseCase } from './load-plan-task-schedule.usecase';
import { LoadPlanVsActualSummaryUseCase } from './load-plan-vs-actual-summary.usecase';
import { LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT } from './load-plan-vs-actual-summary.output-port';
import { LoadStageGddCalibrationProposalsUseCase } from './load-stage-gdd-calibration-proposals.usecase';
import { LOAD_STAGE_GDD_CALIBRATION_PROPOSALS_OUTPUT_PORT } from './load-stage-gdd-calibration-proposals.output-port';
import { PLAN_GATEWAY } from './plan-gateway';
import { LoadBlueprintTimingAdjustmentProposalsUseCase } from './load-blueprint-timing-adjustment-proposals.usecase';
import { LOAD_BLUEPRINT_TIMING_ADJUSTMENT_PROPOSALS_OUTPUT_PORT } from './load-blueprint-timing-adjustment-proposals.output-port';

export const PLAN_LEARN_PROVIDERS: readonly Provider[] = [
  PlanLearnPresenter,
  LoadPlanTaskScheduleUseCase,
  LoadPlanVsActualSummaryUseCase,
  LoadBlueprintTimingAdjustmentProposalsUseCase,
  LoadStageGddCalibrationProposalsUseCase,
  { provide: LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT, useExisting: PlanLearnPresenter },
  {
    provide: LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT,
    useFactory: (
      presenter: PlanLearnPresenter,
      blueprintProposalsUseCase: LoadBlueprintTimingAdjustmentProposalsUseCase,
      stageGddProposalsUseCase: LoadStageGddCalibrationProposalsUseCase
    ) => ({
      present: (dto: Parameters<PlanLearnPresenter['presentVarianceSummary']>[0]) => {
        presenter.presentVarianceSummary(dto);
        const rawBlueprintProposals = dto.summary.blueprint_timing_adjustment_proposals ?? [];
        if (rawBlueprintProposals.length > 0) {
          const loadGeneration = presenter.beginBlueprintTimingProposalsLoad();
          blueprintProposalsUseCase.execute({ rawProposals: rawBlueprintProposals, loadGeneration });
        }
        const rawStageGddProposals = dto.summary.stage_gdd_calibration_proposals ?? [];
        if (rawStageGddProposals.length > 0) {
          const loadGeneration = presenter.beginStageGddProposalsLoad();
          stageGddProposalsUseCase.execute({ rawProposals: rawStageGddProposals, loadGeneration });
        }
      },
      onError: (dto: Parameters<PlanLearnPresenter['onVarianceError']>[0]) =>
        presenter.onVarianceError(dto)
    }),
    deps: [
      PlanLearnPresenter,
      LoadBlueprintTimingAdjustmentProposalsUseCase,
      LoadStageGddCalibrationProposalsUseCase
    ]
  },
  {
    provide: LOAD_BLUEPRINT_TIMING_ADJUSTMENT_PROPOSALS_OUTPUT_PORT,
    useExisting: PlanLearnPresenter
  },
  {
    provide: LOAD_STAGE_GDD_CALIBRATION_PROPOSALS_OUTPUT_PORT,
    useExisting: PlanLearnPresenter
  },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useClass: CropTaskScheduleBlueprintApiGateway },
  { provide: CROP_GATEWAY, useClass: CropApiGateway }
];

export { PlanLearnPresenter } from '../../adapters/plans/plan-learn.presenter';
