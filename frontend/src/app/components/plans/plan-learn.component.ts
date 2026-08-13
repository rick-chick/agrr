import { ChangeDetectorRef, Component, DestroyRef, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { TaskScheduleVarianceViewComponent } from './task-schedule-variance-view.component';
import { StageGddCalibrationProposalsViewComponent } from './stage-gdd-calibration-proposals-view.component';
import { VarianceActionProposalCardsComponent } from './variance-action-proposal-cards.component';
import { BlueprintTimingAdjustmentProposalsViewComponent } from './blueprint-timing-adjustment-proposals-view.component';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
import { PlanLearnApplicationProgressViewComponent } from './plan-learn-application-progress-view.component';
import { PlanLearnPostMasterConfirmationComponent } from './plan-learn-post-master-confirmation.component';
import { PlanLearnMasterUpdateNextStepsComponent } from './plan-learn-master-update-next-steps.component';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { LoadPlanVsActualSummaryUseCase } from '../../usecase/plans/load-plan-vs-actual-summary.usecase';
import { PLAN_LEARN_PROVIDERS, PlanLearnPresenter } from '../../usecase/plans/plan-learn.providers';
import { PlanLearnView, PlanLearnViewState } from './plan-learn.view';
import {
  clearLearnPostMasterPayload,
  parsePlanLearnFollowUp,
  readLearnPostMasterPayload
} from '../../domain/plans/learn-proposal-application-progress';
import { hasPendingMasterUpdateConfirmation } from '../../domain/plans/learn-master-update-orchestration';

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
  postMasterPayload: null
};

@Component({
  selector: 'app-plan-learn',
  standalone: true,
  imports: [
    CommonModule,
    TranslateModule,
    PlanPlanContextHeaderComponent,
    PlanLearnApplicationProgressViewComponent,
    PlanLearnPostMasterConfirmationComponent,
    PlanLearnMasterUpdateNextStepsComponent,
    TaskScheduleVarianceViewComponent,
    StageGddCalibrationProposalsViewComponent,
    VarianceActionProposalCardsComponent,
    BlueprintTimingAdjustmentProposalsViewComponent
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
          <app-variance-action-proposal-cards
            [planId]="planId"
            [items]="control.varianceSummary?.action_required_items ?? []"
          />
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
  private readonly presenter = inject(PlanLearnPresenter);
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
      this.showPostMasterConfirmation || hasPendingMasterUpdateConfirmation(this.planId)
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
  }
}
