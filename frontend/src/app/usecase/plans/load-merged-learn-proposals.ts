import type { PlanLearnPresenter } from '../../adapters/plans/plan-learn.presenter';
import { collectLearnProposalRawSources } from '../../domain/plans/collect-learn-proposal-raw-sources';
import type { PlanVarianceLearningSnapshot } from '../../domain/plans/plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import type { LoadBlueprintTimingAdjustmentProposalsUseCase } from './load-blueprint-timing-adjustment-proposals.usecase';
import type { LoadStageGddCalibrationProposalsUseCase } from './load-stage-gdd-calibration-proposals.usecase';

export function loadMergedLearnProposals(
  presenter: PlanLearnPresenter,
  blueprintProposalsUseCase: LoadBlueprintTimingAdjustmentProposalsUseCase,
  stageGddProposalsUseCase: LoadStageGddCalibrationProposalsUseCase,
  varianceSummary: PlanVsActualSummary | null,
  learningSnapshot: PlanVarianceLearningSnapshot | null
): void {
  const { stageGddCalibrationProposals, blueprintTimingAdjustmentProposals } =
    collectLearnProposalRawSources(varianceSummary, learningSnapshot);

  if (blueprintTimingAdjustmentProposals.length > 0) {
    const loadGeneration = presenter.beginBlueprintTimingProposalsLoad();
    blueprintProposalsUseCase.execute({
      rawProposals: blueprintTimingAdjustmentProposals,
      loadGeneration
    });
  } else {
    presenter.presentBlueprintTimingProposals({
      loadGeneration: presenter.beginBlueprintTimingProposalsLoad(),
      proposals: []
    });
  }

  if (stageGddCalibrationProposals.length > 0) {
    const loadGeneration = presenter.beginStageGddProposalsLoad();
    stageGddProposalsUseCase.execute({
      rawProposals: stageGddCalibrationProposals,
      loadGeneration
    });
  } else {
    presenter.presentStageGddProposals({
      loadGeneration: presenter.beginStageGddProposalsLoad(),
      proposals: []
    });
  }
}
