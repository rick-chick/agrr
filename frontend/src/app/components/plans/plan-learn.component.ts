import { ChangeDetectorRef, Component, DestroyRef, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { TaskScheduleVarianceViewComponent } from './task-schedule-variance-view.component';
import { StageGddCalibrationProposalsViewComponent } from './stage-gdd-calibration-proposals-view.component';
import { VarianceActionProposalCardsComponent } from './variance-action-proposal-cards.component';
import { BlueprintTimingAdjustmentProposalsViewComponent } from './blueprint-timing-adjustment-proposals-view.component';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
import { PlanLearnImportedBannerComponent } from './plan-learn-imported-banner.component';
import { PlanLearnLoopProgressComponent } from './plan-learn-loop-progress.component';
import { PlanLearnObservePhaseStatusComponent } from './plan-learn-observe-phase-status.component';
import { PlanLearnInputGapSummaryComponent } from './plan-learn-input-gap-summary.component';
import { resolveLearnObservePhaseStatus } from '../../domain/plans/resolve-learn-observe-phase-status';
import { buildPlanInputGapSummary } from '../../domain/plans/build-plan-input-gap-summary';
import { resolveLearnProposalConfidence } from '../../domain/plans/resolve-learn-proposal-confidence';
import { resolvePlanWorkHighlightItemId } from '../../domain/plans/build-plan-work-deep-link-query';
import { PlanLearnApplicationProgressViewComponent } from './plan-learn-application-progress-view.component';
import { PlanLearnPostMasterConfirmationComponent } from './plan-learn-post-master-confirmation.component';
import { PlanLearnMasterUpdateNextStepsComponent } from './plan-learn-master-update-next-steps.component';
import { PlanLearnBulkApplyPanelComponent } from './plan-learn-bulk-apply-panel.component';
import { PlanLearnPipelineStatusComponent } from './plan-learn-pipeline-status.component';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { LoadPlanVsActualSummaryUseCase } from '../../usecase/plans/load-plan-vs-actual-summary.usecase';
import { LoadPlanLearnCarryoverUseCase } from '../../usecase/plans/load-plan-learn-carryover.usecase';
import { PlanLearnCarryoverSectionComponent } from './plan-learn-carryover-section.component';
import { planCarryoverNextPlanCtaVisible } from '../../domain/plans/plan-carryover-handoff';
import { isLearnLoopComplete } from '../../domain/plans/learn-loop-phase';
import { LoadBlueprintTimingAdjustmentProposalsUseCase } from '../../usecase/plans/load-blueprint-timing-adjustment-proposals.usecase';
import { LoadStageGddCalibrationProposalsUseCase } from '../../usecase/plans/load-stage-gdd-calibration-proposals.usecase';
import { loadMergedLearnProposals } from '../../usecase/plans/load-merged-learn-proposals';
import { countMergedLearnProposals } from '../../domain/plans/count-merged-learn-proposals';
import { PLAN_LEARN_PROVIDERS, PlanLearnPresenter } from '../../usecase/plans/plan-learn.providers';
import { PlanLearnView, PlanLearnViewState } from './plan-learn.view';
import type { PlanVsActualCategorySummary } from '../../domain/plans/plan-vs-actual-summary';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';
import {
  clearLearnPostMasterPayload,
  confirmLearnProposalFromPostMaster,
  parsePlanLearnFollowUp,
  readLearnPostMasterPayload
} from '../../domain/plans/learn-proposal-application-progress';
import { hasActiveLearnMasterUpdateFlow } from '../../domain/plans/learn-master-update-orchestration';

const initialControl: PlanLearnViewState = {
  loading: true,
  error: null,
  planName: null,
  varianceLoading: true,
  varianceError: null,
  varianceSummary: null,
  varianceStats: null,
  varianceUnrecordedRows: [],
  blueprintTimingLoading: false,
  blueprintTimingProposals: [],
  blueprintTimingEvidenceByKey: {},
  stageGddProposalsLoading: false,
  stageGddProposals: [],
  stageGddEvidenceByKey: {},
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

@Component({
  selector: 'app-plan-learn',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    TranslateModule,
    PlanPlanContextHeaderComponent,
    PlanLearnApplicationProgressViewComponent,
    PlanLearnPostMasterConfirmationComponent,
    PlanLearnMasterUpdateNextStepsComponent,
    PlanLearnBulkApplyPanelComponent,
    PlanLearnPipelineStatusComponent,
    TaskScheduleVarianceViewComponent,
    StageGddCalibrationProposalsViewComponent,
    VarianceActionProposalCardsComponent,
    BlueprintTimingAdjustmentProposalsViewComponent,
    PlanLearnImportedBannerComponent,
    PlanLearnLoopProgressComponent,
    PlanLearnObservePhaseStatusComponent,
    PlanLearnInputGapSummaryComponent,
    PlanLearnCarryoverSectionComponent
  ],
  providers: [...PLAN_LEARN_PROVIDERS],
  template: `
    <div class="page-main page-main--fit">
      <app-plan-plan-context-header
        [planId]="planId"
        [planName]="control.planName"
        pageTitleKey="plans.learn.page_title"
      />

      <section class="section-card" aria-labelledby="plan-context-page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error plan-work__error" role="alert">
            <p>{{ control.error | translate }}</p>
            <button type="button" class="btn-secondary plan-work__retry" (click)="reload()">
              {{ 'plans.work.retry' | translate }}
            </button>
          </div>
        } @else {
          <app-plan-learn-loop-progress
            [planId]="planId"
            [actionRequiredItems]="control.varianceSummary?.action_required_items ?? []"
            [stageGddProposals]="control.stageGddProposals"
            [blueprintTimingProposals]="control.blueprintTimingProposals"
            [hasPostMasterConfirmation]="showPostMasterConfirmation"
            [hasMasterUpdateNextSteps]="showMasterUpdateNextSteps"
            [hasLearningSnapshot]="control.learningSnapshot != null"
            [carryoverSourcePlanCount]="control.carryoverSourcePlans.length"
            [progressRefreshVersion]="proposalProgressRefreshVersion"
          />
          <app-plan-learn-input-gap-summary
            [planId]="planId"
            [summary]="inputGapSummary"
            [loading]="control.varianceLoading"
            [error]="control.varianceError"
            [highlightItemId]="workHighlightItemId"
          />
          <app-plan-learn-observe-phase-status
            [planId]="planId"
            [status]="observePhaseStatus"
            [unrecordedCount]="control.varianceSummary?.unrecorded_count ?? 0"
            [highlightItemId]="workHighlightItemId"
          />
          @if (showPostMasterConfirmation) {
            <app-plan-learn-post-master-confirmation
              [planId]="planId"
              [payload]="control.postMasterPayload"
            />
          }
          <app-plan-learn-master-update-next-steps
            [planId]="planId"
            [visible]="true"
          />
          <app-plan-learn-pipeline-status
            [planId]="planId"
            [refreshVersion]="proposalProgressRefreshVersion"
          />
          <app-plan-learn-bulk-apply-panel
            [planId]="planId"
            [stageGddProposals]="control.stageGddProposals"
            [blueprintTimingProposals]="control.blueprintTimingProposals"
            [progressRefreshVersion]="proposalProgressRefreshVersion"
            (progressChanged)="onProposalProgressChanged()"
          />
          <app-plan-learn-application-progress-view
            [planId]="planId"
            [stageGddProposals]="control.stageGddProposals"
            [blueprintTimingProposals]="control.blueprintTimingProposals"
            [progressRefreshVersion]="proposalProgressRefreshVersion"
          />
          @if (control.learningSnapshot; as learningSnapshot) {
            @if (learningSnapshot.source_plan_id != null && learningSnapshot.summary) {
            <div class="plan-learn-imported-snapshot" aria-labelledby="plan-learn-imported-title">
              <h3 id="plan-learn-imported-title" class="plan-learn-imported-snapshot__title">
                {{
                  'plans.learn.imported_snapshot_title'
                    | translate: { sourcePlanId: learningSnapshot.source_plan_id }
                }}
              </h3>
              @if (learningSnapshot.summary.categories.length) {
                <table class="plan-learn-carryover-preview__table">
                  <thead>
                    <tr>
                      <th scope="col">{{
                        'plans.task_schedules.variance_subview.category_column' | translate
                      }}</th>
                      <th scope="col">{{
                        'plans.task_schedules.variance_subview.category_average' | translate
                      }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    @for (
                      category of learningSnapshot.summary.categories;
                      track category.category
                    ) {
                      <tr>
                        <td>{{ categoryLabel(category) }}</td>
                        <td>{{ categoryAverageLabel(category) }}</td>
                      </tr>
                    }
                  </tbody>
                </table>
              } @else {
                <p class="plan-learn-carryover__hint">{{
                  'plans.learn.imported_snapshot_empty' | translate
                }}</p>
              }
            </div>
            <app-plan-learn-imported-banner
              [planId]="planId"
              [items]="learningSnapshot.summary.action_required_items ?? []"
              [mergedProposalCount]="mergedProposalCount"
            />
            }
          }

          <app-plan-learn-carryover-section
            [planId]="planId"
            [carryoverSourcePlans]="control.carryoverSourcePlans"
            [selectedSourcePlanId]="control.selectedSourcePlanId"
            [carryoverPreviewLoading]="control.carryoverPreviewLoading"
            [carryoverPreviewError]="control.carryoverPreviewError"
            [carryoverPreview]="control.carryoverPreview"
            [carryoverImporting]="control.carryoverImporting"
            [carryoverImportError]="control.carryoverImportError"
            [showNextPlanCta]="showCarryoverNextPlanCta"
            (sourcePlanChange)="onSourcePlanChange($event)"
            (importLearning)="onImportLearning()"
          />

          <app-variance-action-proposal-cards
            [planId]="planId"
            [items]="control.varianceSummary?.action_required_items ?? []"
            [proposalConfidence]="proposalConfidence"
          />
          <div id="plan-learn-loop-proposals">
          <h3 id="plan-learn-current-variance-title" class="plan-learn-current-variance__title">
            {{ 'plans.learn.current_variance_title' | translate }}
          </h3>
          <p class="plan-learn-current-variance__hint">
            {{ 'plans.learn.current_variance_hint' | translate }}
          </p>
          <app-blueprint-timing-adjustment-proposals-view
            [planId]="planId"
            [loading]="control.blueprintTimingLoading"
            [proposals]="control.blueprintTimingProposals"
            [evidenceByKey]="control.blueprintTimingEvidenceByKey"
            [proposalConfidence]="proposalConfidence"
            (progressChanged)="onProposalProgressChanged()"
          />
          <app-task-schedule-variance-view
            [planId]="planId"
            [loading]="control.varianceLoading"
            [error]="control.varianceError"
            [stats]="control.varianceStats"
            [summary]="control.varianceSummary"
            [unrecordedRows]="control.varianceUnrecordedRows"
          />
          <app-stage-gdd-calibration-proposals-view
            [planId]="planId"
            [loading]="control.stageGddProposalsLoading"
            [proposals]="control.stageGddProposals"
            [evidenceByKey]="control.stageGddEvidenceByKey"
            [proposalConfidence]="proposalConfidence"
            (progressChanged)="onProposalProgressChanged()"
          />
          </div>
        }
      </section>
    </div>
  `,
  styleUrls: ['./plan-learn.component.css']
})
export class PlanLearnComponent implements PlanLearnView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly scheduleUseCase = inject(LoadPlanTaskScheduleUseCase);
  private readonly varianceUseCase = inject(LoadPlanVsActualSummaryUseCase);
  private readonly carryoverUseCase = inject(LoadPlanLearnCarryoverUseCase);
  private readonly blueprintTimingUseCase = inject(LoadBlueprintTimingAdjustmentProposalsUseCase);
  private readonly stageGddProposalsUseCase = inject(LoadStageGddCalibrationProposalsUseCase);
  private readonly presenter = inject(PlanLearnPresenter);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  proposalProgressRefreshVersion = 0;

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  private _control: PlanLearnViewState = initialControl;
  get control(): PlanLearnViewState {
    return this._control;
  }
  set control(value: PlanLearnViewState) {
    const prevVarianceLoading = this._control.varianceLoading;
    this._control = value;
    this.cdr.markForCheck();
    if (prevVarianceLoading && !value.varianceLoading && !value.varianceError) {
      this.scrollToVarianceSectionIfRequested();
    }
  }

  get showPostMasterConfirmation(): boolean {
    return this.control.postMasterPayload != null;
  }

  get showMasterUpdateNextSteps(): boolean {
    return (
      this.showPostMasterConfirmation || hasActiveLearnMasterUpdateFlow(this.planId)
    );
  }

  get mergedProposalCount(): number {
    return countMergedLearnProposals(
      this.control.varianceSummary,
      this.control.learningSnapshot
    );
  }

  get observePhaseStatus(): ReturnType<typeof resolveLearnObservePhaseStatus> {
    return resolveLearnObservePhaseStatus({
      varianceLoading: this.control.varianceLoading,
      varianceError: this.control.varianceError,
      unrecordedCount: this.control.varianceSummary?.unrecorded_count ?? null
    });
  }

  get inputGapSummary(): ReturnType<typeof buildPlanInputGapSummary> | null {
    if (!this.control.varianceSummary) {
      return null;
    }
    return buildPlanInputGapSummary(this.control.varianceSummary);
  }

  get workHighlightItemId(): number | null {
    return resolvePlanWorkHighlightItemId(this.control.varianceUnrecordedRows);
  }

  get showCarryoverNextPlanCta(): boolean {
    return planCarryoverNextPlanCtaVisible({
      hasLearningSnapshot: this.control.learningSnapshot != null,
      loopComplete: isLearnLoopComplete(
        this.planId,
        this.control.stageGddProposals,
        this.control.blueprintTimingProposals
      )
    });
  }

  get proposalConfidence(): ReturnType<typeof resolveLearnProposalConfidence> {
    const summary = this.inputGapSummary;
    if (!summary) {
      return 'high';
    }
    return resolveLearnProposalConfidence(summary);
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.route.paramMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => this.reload());
    this.route.queryParamMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => {
      this.syncPostMasterFollowUp();
    });
    this.syncPostMasterFollowUp();
    this.scrollToVarianceSectionIfRequested();
  }

  private syncPostMasterFollowUp(): void {
    const planId = this.planId;
    if (!planId) {
      return;
    }
    const followUp = parsePlanLearnFollowUp(this.route.snapshot.queryParamMap.get('followUp'));
    if (followUp !== 'post_master') {
      if (this.control.postMasterPayload != null) {
        this.control = { ...this.control, postMasterPayload: null };
      }
      return;
    }
    const payload = readLearnPostMasterPayload(planId);
    if (!payload) {
      return;
    }
    confirmLearnProposalFromPostMaster(planId, payload);
    this.control = { ...this.control, postMasterPayload: payload };
    clearLearnPostMasterPayload(planId);
  }

  onProposalProgressChanged(): void {
    this.proposalProgressRefreshVersion += 1;
    this.cdr.markForCheck();
  }

  reload(): void {
    const planId = this.planId;
    if (!planId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: 'plans.errors.invalid_id',
        varianceLoading: false
      };
      return;
    }
    this.control = {
      ...initialControl,
      loading: true,
      error: null,
      varianceLoading: true,
      varianceError: null
    };
    this.scheduleUseCase.execute({ planId, loadGeneration: 0 });
    const loadGeneration = this.presenter.beginVarianceLoad();
    this.varianceUseCase.execute({ planId, loadGeneration });
    this.loadLearningSnapshot(planId);
    this.loadCarryoverContext(planId);
  }

  onSourcePlanChange(planId: number | null): void {
    this.control = {
      ...this.control,
      selectedSourcePlanId: planId,
      carryoverPreview: null,
      carryoverPreviewError: null,
      carryoverPreviewLoading: planId != null,
      carryoverImportError: null
    };
    if (planId != null) {
      this.loadCarryoverPreview(planId);
    }
  }

  onImportLearning(): void {
    const sourcePlanId = this.control.selectedSourcePlanId;
    if (sourcePlanId == null || this.control.carryoverImporting) {
      return;
    }
    this.control = {
      ...this.control,
      carryoverImporting: true,
      carryoverImportError: null
    };
    this.carryoverUseCase
      .importLearning(this.planId, sourcePlanId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (snapshot) => {
          this.control = {
            ...this.control,
            carryoverImporting: false,
            learningSnapshot: snapshot,
            carryoverImportError: null
          };
          loadMergedLearnProposals(
            this.presenter,
            this.blueprintTimingUseCase,
            this.stageGddProposalsUseCase,
            this.control.varianceSummary,
            snapshot
          );
        },
        error: (err: Error) => {
          this.control = {
            ...this.control,
            carryoverImporting: false,
            carryoverImportError: err.message
          };
        }
      });
  }

  private scrollToVarianceSectionIfRequested(): void {
    if (this.route.snapshot.fragment !== 'plan-learn-current-variance-title') {
      return;
    }
    requestAnimationFrame(() => {
      document.getElementById('plan-learn-current-variance-title')?.scrollIntoView({
        behavior: 'smooth',
        block: 'start'
      });
    });
  }

  private scrollToImportedSnapshotIfRequested(): void {
    const expand = this.route.snapshot.queryParamMap.get('expand');
    if (expand !== 'imported_snapshot' && expand !== 'carryover') {
      return;
    }
    requestAnimationFrame(() => {
      document.getElementById('plan-learn-imported-title')?.scrollIntoView({
        behavior: 'smooth',
        block: 'start'
      });
    });
  }

  categoryLabel(category: PlanVsActualCategorySummary): string {
    return this.translate.instant(
      `plans.task_schedules.variance_subview.category.${category.category}`
    );
  }

  categoryAverageLabel(category: PlanVsActualCategorySummary): string {
    if (category.average_delta_days == null) {
      return this.translate.instant('plans.task_schedules.variance_subview.not_available');
    }
    return this.translate.instant('plans.task_schedules.variance_subview.average_value', {
      delta: formatPlanTaskScheduleAverageDeltaDaysLabel(category.average_delta_days)
    });
  }

  private loadLearningSnapshot(planId: number): void {
    this.carryoverUseCase
      .loadLearningSnapshot(planId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (snapshot) => {
          this.control = {
            ...this.control,
            learningSnapshot: snapshot
          };
          if (snapshot) {
            loadMergedLearnProposals(
              this.presenter,
              this.blueprintTimingUseCase,
              this.stageGddProposalsUseCase,
              this.control.varianceSummary,
              snapshot
            );
            this.scrollToImportedSnapshotIfRequested();
          }
        }
      });
  }

  private loadCarryoverContext(planId: number): void {
    this.carryoverUseCase
      .loadFarmContext(planId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (sourcePlans) => {
          this.control = {
            ...this.control,
            carryoverSourcePlans: sourcePlans
          };
        }
      });
  }

  private loadCarryoverPreview(sourcePlanId: number): void {
    this.carryoverUseCase
      .loadCarryoverPreview(sourcePlanId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (summary) => {
          this.control = {
            ...this.control,
            carryoverPreviewLoading: false,
            carryoverPreviewError: null,
            carryoverPreview: summary
          };
        },
        error: (err: Error) => {
          this.control = {
            ...this.control,
            carryoverPreviewLoading: false,
            carryoverPreviewError: err.message,
            carryoverPreview: null
          };
        }
      });
  }
}
