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
import { PlanLearnApplicationProgressViewComponent } from './plan-learn-application-progress-view.component';
import { PlanLearnPostMasterConfirmationComponent } from './plan-learn-post-master-confirmation.component';
import { PlanLearnMasterUpdateNextStepsComponent } from './plan-learn-master-update-next-steps.component';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { LoadPlanVsActualSummaryUseCase } from '../../usecase/plans/load-plan-vs-actual-summary.usecase';
import { LoadPlanLearnCarryoverUseCase } from '../../usecase/plans/load-plan-learn-carryover.usecase';
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
  stageGddProposalsLoading: false,
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
    TaskScheduleVarianceViewComponent,
    StageGddCalibrationProposalsViewComponent,
    VarianceActionProposalCardsComponent,
    BlueprintTimingAdjustmentProposalsViewComponent,
    PlanLearnImportedBannerComponent,
    PlanLearnLoopProgressComponent
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
          />
          @if (showPostMasterConfirmation) {
            <app-plan-learn-post-master-confirmation
              [planId]="planId"
              [payload]="control.postMasterPayload"
            />
          }
          <app-plan-learn-master-update-next-steps
            [planId]="planId"
            [visible]="showMasterUpdateNextSteps"
          />
          <app-plan-learn-application-progress-view
            [planId]="planId"
            [stageGddProposals]="control.stageGddProposals"
            [blueprintTimingProposals]="control.blueprintTimingProposals"
          />
          @if (control.learningSnapshot) {
            <div class="plan-learn-imported-snapshot" aria-labelledby="plan-learn-imported-title">
              <h3 id="plan-learn-imported-title" class="plan-learn-imported-snapshot__title">
                {{
                  'plans.learn.imported_snapshot_title'
                    | translate: { sourcePlanId: control.learningSnapshot.source_plan_id }
                }}
              </h3>
              @if (control.learningSnapshot.summary.categories.length) {
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
                      category of control.learningSnapshot.summary.categories;
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
              [items]="control.learningSnapshot.summary.action_required_items ?? []"
            />
          }

          <div class="plan-learn-carryover" aria-labelledby="plan-learn-carryover-title">
            <h3 id="plan-learn-carryover-title" class="plan-learn-carryover__title">
              {{ 'plans.learn.carryover.title' | translate }}
            </h3>
            <p class="plan-learn-carryover__hint">{{ 'plans.learn.carryover.hint' | translate }}</p>
            @if (control.carryoverSourcePlans.length === 0) {
              <p class="plan-learn-carryover__hint">{{
                'plans.learn.carryover.no_source_plans' | translate
              }}</p>
            } @else {
              <div class="plan-learn-carryover__form">
                <label for="plan-learn-carryover-source" class="plan-learn-carryover__label">{{
                  'plans.learn.carryover.source_label' | translate
                }}</label>
                <select
                  id="plan-learn-carryover-source"
                  class="plan-learn-carryover__select"
                  [disabled]="control.carryoverImporting"
                  [ngModel]="control.selectedSourcePlanId"
                  (ngModelChange)="onSourcePlanChange($event)"
                >
                  <option [ngValue]="null">{{
                    'plans.learn.carryover.source_hint' | translate
                  }}</option>
                  @for (plan of control.carryoverSourcePlans; track plan.id) {
                    <option [ngValue]="plan.id">{{ plan.name }}</option>
                  }
                </select>
                @if (control.selectedSourcePlanId != null) {
                  @if (control.carryoverPreviewLoading) {
                    <p class="master-loading">{{ 'common.loading' | translate }}</p>
                  } @else if (control.carryoverPreviewError) {
                    <p class="plan-learn-carryover__error">{{ control.carryoverPreviewError }}</p>
                  } @else if (control.carryoverPreview) {
                    <div class="plan-learn-carryover-preview">
                      <h4 class="plan-learn-carryover-preview__title">{{
                        'plans.learn.carryover.preview_title' | translate
                      }}</h4>
                      @if (control.carryoverPreview.categories.length) {
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
                            @for (category of control.carryoverPreview.categories; track category.category) {
                              <tr>
                                <td>{{ categoryLabel(category) }}</td>
                                <td>{{ categoryAverageLabel(category) }}</td>
                              </tr>
                            }
                          </tbody>
                        </table>
                      } @else {
                        <p class="plan-learn-carryover__hint">{{
                          'plans.learn.carryover.preview_empty' | translate
                        }}</p>
                      }
                      <button
                        type="button"
                        class="btn btn-primary"
                        [disabled]="control.carryoverImporting"
                        (click)="onImportLearning()"
                      >
                        {{
                          control.carryoverImporting
                            ? ('common.loading' | translate)
                            : ('plans.learn.carryover.import_button' | translate)
                        }}
                      </button>
                      @if (control.carryoverImportError) {
                        <p class="plan-learn-carryover__error">{{ control.carryoverImportError }}</p>
                      }
                    </div>
                  }
                }
              </div>
            }
          </div>

          <app-variance-action-proposal-cards
            [planId]="planId"
            [items]="control.varianceSummary?.action_required_items ?? []"
          />
          <div id="plan-learn-loop-proposals">
          <app-blueprint-timing-adjustment-proposals-view
            [planId]="planId"
            [loading]="control.blueprintTimingLoading"
            [proposals]="control.blueprintTimingProposals"
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
  private readonly presenter = inject(PlanLearnPresenter);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  private _control: PlanLearnViewState = initialControl;
  get control(): PlanLearnViewState {
    return this._control;
  }
  set control(value: PlanLearnViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  get showPostMasterConfirmation(): boolean {
    return this.control.postMasterPayload != null;
  }

  get showMasterUpdateNextSteps(): boolean {
    return (
      this.showPostMasterConfirmation || hasActiveLearnMasterUpdateFlow(this.planId)
    );
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.route.paramMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => this.reload());
    this.route.queryParamMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => {
      this.syncPostMasterFollowUp();
    });
    this.syncPostMasterFollowUp();
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
