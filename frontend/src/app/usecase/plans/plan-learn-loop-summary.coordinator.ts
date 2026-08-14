import { DestroyRef, Injectable, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import type { PlanLearnView, PlanLearnViewState } from '../../components/plans/plan-learn.view';
import { PlanLearnPresenter } from './plan-learn.providers';
import { LoadPlanVsActualSummaryUseCase } from './load-plan-vs-actual-summary.usecase';
import { LoadPlanLearnCarryoverUseCase } from './load-plan-learn-carryover.usecase';
import { LoadBlueprintTimingAdjustmentProposalsUseCase } from './load-blueprint-timing-adjustment-proposals.usecase';
import { LoadStageGddCalibrationProposalsUseCase } from './load-stage-gdd-calibration-proposals.usecase';
import { loadMergedLearnProposals } from './load-merged-learn-proposals';
import {
  buildLearnLoopPhaseInputFromState,
  buildLearnLoopPhaseResult
} from '../../domain/plans/learn-loop-phase';
import {
  buildLearnLoopCrossDisplaySummary,
  resolveLearnNavBadge,
  shouldShowLearnNavBadge,
  type LearnLoopCrossDisplaySummary,
  type LearnNavBadge
} from '../../domain/plans/learn-loop-cross-display';
import { hasActiveLearnMasterUpdateFlow } from '../../domain/plans/learn-master-update-orchestration';
import { readLearnPostMasterPayload } from '../../domain/plans/learn-proposal-application-progress';

const initialControl: PlanLearnViewState = {
  loading: false,
  error: null,
  planName: null,
  varianceLoading: true,
  varianceError: null,
  varianceSummary: null,
  varianceStats: null,
  varianceUnrecordedRows: [],
  blueprintTimingLoading: true,
  blueprintTimingProposals: [],
  stageGddProposalsLoading: true,
  stageGddProposals: [],
  learningSnapshot: null,
  carryoverSourcePlans: [],
  selectedSourcePlanId: null,
  carryoverPreviewLoading: false,
  carryoverPreviewError: null,
  carryoverPreview: null,
  carryoverImporting: false,
  carryoverImportError: null,
  postMasterPayload: null
};

export interface PlanLearnLoopSummarySnapshot {
  badge: LearnNavBadge | null;
  crossDisplay: LearnLoopCrossDisplaySummary;
  loading: boolean;
}

@Injectable()
export class PlanLearnLoopSummaryCoordinator implements PlanLearnView {
  private readonly presenter = inject(PlanLearnPresenter);
  private readonly varianceUseCase = inject(LoadPlanVsActualSummaryUseCase);
  private readonly carryoverUseCase = inject(LoadPlanLearnCarryoverUseCase);
  private readonly blueprintTimingUseCase = inject(LoadBlueprintTimingAdjustmentProposalsUseCase);
  private readonly stageGddProposalsUseCase = inject(LoadStageGddCalibrationProposalsUseCase);
  private readonly destroyRef = inject(DestroyRef);

  private _control: PlanLearnViewState = initialControl;
  private activePlanId: number | null = null;
  private listeners = new Set<(snapshot: PlanLearnLoopSummarySnapshot) => void>();

  constructor() {
    this.presenter.setView(this);
  }

  get control(): PlanLearnViewState {
    return this._control;
  }

  set control(value: PlanLearnViewState) {
    this._control = value;
    this.emitSnapshot();
  }

  subscribe(listener: (snapshot: PlanLearnLoopSummarySnapshot) => void): () => void {
    this.listeners.add(listener);
    listener(this.buildSnapshot());
    return () => this.listeners.delete(listener);
  }

  load(planId: number): void {
    if (this.activePlanId === planId && !this._control.varianceLoading) {
      return;
    }
    this.activePlanId = planId;
    this._control = {
      ...initialControl,
      varianceLoading: true,
      blueprintTimingLoading: true,
      stageGddProposalsLoading: true
    };
    this.emitSnapshot();

    const loadGeneration = this.presenter.beginVarianceLoad();
    this.varianceUseCase.execute({ planId, loadGeneration });
    this.loadLearningSnapshot(planId);
    this.loadCarryoverContext(planId);
  }

  private buildSnapshot(): PlanLearnLoopSummarySnapshot {
    const planId = this.activePlanId;
    if (!planId) {
      return {
        badge: null,
        crossDisplay: buildLearnLoopCrossDisplaySummary(
          buildLearnLoopPhaseResult(
            buildLearnLoopPhaseInputFromState({
              planId: 0,
              actionRequiredItems: [],
              stageGddProposals: [],
              blueprintTimingProposals: [],
              hasPostMasterConfirmation: false,
              hasMasterUpdateNextSteps: false,
              hasLearningSnapshot: false,
              carryoverSourcePlanCount: 0
            })
          )
        ),
        loading: true
      };
    }

    const loading =
      this._control.varianceLoading ||
      this._control.blueprintTimingLoading ||
      this._control.stageGddProposalsLoading;

    const phaseInput = buildLearnLoopPhaseInputFromState({
      planId,
      actionRequiredItems: this._control.varianceSummary?.action_required_items ?? [],
      stageGddProposals: this._control.stageGddProposals,
      blueprintTimingProposals: this._control.blueprintTimingProposals,
      hasPostMasterConfirmation: readLearnPostMasterPayload(planId) != null,
      hasMasterUpdateNextSteps: hasActiveLearnMasterUpdateFlow(planId),
      hasLearningSnapshot: this._control.learningSnapshot != null,
      carryoverSourcePlanCount: this._control.carryoverSourcePlans.length
    });
    const phaseResult = buildLearnLoopPhaseResult(phaseInput);
    const showBadge = shouldShowLearnNavBadge({
      actionRequiredCount: phaseInput.actionRequiredCount,
      stageGddProposalCount: phaseInput.stageGddProposalCount,
      blueprintTimingProposalCount: phaseInput.blueprintTimingProposalCount,
      hasActiveMasterUpdateFlow: hasActiveLearnMasterUpdateFlow(planId),
      hasLearningSnapshot: phaseInput.hasLearningSnapshot,
      carryoverSourcePlanCount: phaseInput.carryoverSourcePlanCount
    });

    return {
      badge: loading
        ? null
        : resolveLearnNavBadge({
            notStartedProposalCount: phaseInput.notStartedProposalCount,
            phaseResult,
            showBadge
          }),
      crossDisplay: buildLearnLoopCrossDisplaySummary(phaseResult),
      loading
    };
  }

  private emitSnapshot(): void {
    const snapshot = this.buildSnapshot();
    for (const listener of this.listeners) {
      listener(snapshot);
    }
  }

  private loadLearningSnapshot(planId: number): void {
    this.carryoverUseCase
      .loadLearningSnapshot(planId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (snapshot) => {
          this._control = {
            ...this._control,
            learningSnapshot: snapshot
          };
          if (snapshot) {
            loadMergedLearnProposals(
              this.presenter,
              this.blueprintTimingUseCase,
              this.stageGddProposalsUseCase,
              this._control.varianceSummary,
              snapshot
            );
          }
          this.emitSnapshot();
        }
      });
  }

  private loadCarryoverContext(planId: number): void {
    this.carryoverUseCase
      .loadFarmContext(planId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (sourcePlans) => {
          this._control = {
            ...this._control,
            carryoverSourcePlans: sourcePlans
          };
          this.emitSnapshot();
        }
      });
  }
}
