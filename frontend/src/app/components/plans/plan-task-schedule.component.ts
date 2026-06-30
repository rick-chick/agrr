import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PlanDisplayNamePipe } from '../../core/plan-display-name.pipe';
import { TaskScheduleTimelineComponent } from './task-schedule-timeline.component';
import { PlanTaskScheduleView, PlanTaskScheduleViewState } from './plan-task-schedule.view';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { PlanTaskSchedulePresenter, PLAN_TASK_SCHEDULE_PROVIDERS } from '../../usecase/plans/plan-task-schedule.providers';
import { PlanWorkNavComponent } from './plan-work-nav.component';

const initialControl: PlanTaskScheduleViewState = {
  loading: true,
  error: null,
  schedule: null
};

@Component({
  selector: 'app-plan-task-schedule',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    TaskScheduleTimelineComponent,
    TranslateModule,
    PlanDisplayNamePipe,
    PlanWorkNavComponent
  ],
  providers: [...PLAN_TASK_SCHEDULE_PROVIDERS],
  template: `
    <main class="page-main page-main--fit">
      <header class="page-header">
        <a class="plan-work-header__back" [routerLink]="['/work']">{{
          'plans.work.back_to_hub' | translate
        }}</a>
        @if (control.schedule) {
          <h1 id="plan-work-page-title" class="page-title">{{
            'plans.task_schedules.title'
              | translate: { name: (control.schedule.plan.name | planDisplayName) }
          }}</h1>
          <p class="page-description">
            <a class="plan-work-header__plan-link" [routerLink]="['/plans', planId]">{{
              'plans.task_schedules.back_to_plan' | translate
            }}</a>
          </p>
        }
      </header>

      <section class="section-card" aria-labelledby="plan-work-page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error plan-work__error" role="alert">
            <p>{{ control.error | translate }}</p>
            <button type="button" class="btn-secondary plan-work__retry" (click)="reload()">
              {{ 'plans.work.retry' | translate }}
            </button>
          </div>
        } @else if (control.schedule) {
          <app-plan-work-nav [planId]="planId" />
          <app-task-schedule-timeline [fields]="control.schedule.fields" />
        }
      </section>
    </main>
  `,
  styleUrls: ['./plan-task-schedule.component.css']
})
export class PlanTaskScheduleComponent implements PlanTaskScheduleView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadPlanTaskScheduleUseCase);
  private readonly presenter = inject(PlanTaskSchedulePresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  private _control: PlanTaskScheduleViewState = initialControl;
  get control(): PlanTaskScheduleViewState {
    return this._control;
  }
  set control(value: PlanTaskScheduleViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const planId = this.planId;
    if (!planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    this.reload();
  }

  reload(): void {
    const planId = this.planId;
    if (!planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    this.control = { ...this.control, loading: true, error: null };
    this.useCase.execute({ planId });
  }
}
