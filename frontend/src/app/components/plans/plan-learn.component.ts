import { ChangeDetectorRef, Component, DestroyRef, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { TaskScheduleVarianceViewComponent } from './task-schedule-variance-view.component';
import { StageGddCalibrationProposalsViewComponent } from './stage-gdd-calibration-proposals-view.component';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { LoadPlanVsActualSummaryUseCase } from '../../usecase/plans/load-plan-vs-actual-summary.usecase';
import { PLAN_LEARN_PROVIDERS, PlanLearnPresenter } from '../../usecase/plans/plan-learn.providers';
import { PlanLearnView, PlanLearnViewState } from './plan-learn.view';

const initialControl: PlanLearnViewState = {
  loading: true,
  error: null,
  planName: null,
  varianceLoading: true,
  varianceError: null,
  varianceSummary: null,
  varianceStats: null,
  varianceUnrecordedRows: [],
  stageGddProposalsLoading: false,
  stageGddProposals: []
};

@Component({
  selector: 'app-plan-learn',
  standalone: true,
  imports: [
    CommonModule,
    TranslateModule,
    PlanPlanContextHeaderComponent,
    TaskScheduleVarianceViewComponent,
    StageGddCalibrationProposalsViewComponent
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

  ngOnInit(): void {
    this.presenter.setView(this);
    this.route.paramMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => this.reload());
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
