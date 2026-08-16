import type { PlanLearnPresenter } from '../../adapters/plans/plan-learn.presenter';
import { collectLearnProposalRawSources } from '../../domain/plans/collect-learn-proposal-raw-sources';
import type { PlanVarianceLearningSnapshot } from '../../domain/plans/plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import type { LoadBlueprintAmountAdjustmentProposalsUseCase } from './load-blueprint-amount-adjustment-proposals.usecase';
import type { LoadBlueprintTimingAdjustmentProposalsUseCase } from './load-blueprint-timing-adjustment-proposals.usecase';
import type { LoadStageGddCalibrationProposalsUseCase } from './load-stage-gdd-calibration-proposals.usecase';

export function loadMergedLearnProposals(
  presenter: PlanLearnPresenter,
  blueprintTimingProposalsUseCase: LoadBlueprintTimingAdjustmentProposalsUseCase,
  blueprintAmountProposalsUseCase: LoadBlueprintAmountAdjustmentProposalsUseCase,
  stageGddProposalsUseCase: LoadStageGddCalibrationProposalsUseCase,
  varianceSummary: PlanVsActualSummary | null,
  learningSnapshot: PlanVarianceLearningSnapshot | null
): void {
  const {
    stageGddCalibrationProposals,
    blueprintTimingAdjustmentProposals,
    blueprintAmountAdjustmentProposals
  } = collectLearnProposalRawSources(varianceSummary, learningSnapshot);

  if (blueprintTimingAdjustmentProposals.length > 0) {
    const loadGeneration = presenter.beginBlueprintTimingProposalsLoad();
    blueprintTimingProposalsUseCase.execute({
      rawProposals: blueprintTimingAdjustmentProposals,
      loadGeneration
    });
  } else {
    presenter.presentBlueprintTimingProposals({
      loadGeneration: presenter.beginBlueprintTimingProposalsLoad(),
      proposals: []
    });
  }

  if (blueprintAmountAdjustmentProposals.length > 0) {
    const loadGeneration = presenter.beginBlueprintAmountProposalsLoad();
    blueprintAmountProposalsUseCase.execute({
      rawProposals: blueprintAmountAdjustmentProposals,
      loadGeneration
    });
  } else {
    presenter.presentBlueprintAmountProposals({
      loadGeneration: presenter.beginBlueprintAmountProposalsLoad(),
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
