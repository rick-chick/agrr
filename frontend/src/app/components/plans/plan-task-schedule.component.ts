import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { TaskScheduleTimelineComponent } from './task-schedule-timeline.component';
import { PlanTaskScheduleView, PlanTaskScheduleViewState } from './plan-task-schedule.view';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { PlanTaskSchedulePresenter, PLAN_TASK_SCHEDULE_PROVIDERS } from '../../usecase/plans/plan-task-schedule.providers';

const initialControl: PlanTaskScheduleViewState = {
  loading: true,
  error: null,
  schedule: null
};

@Component({
  selector: 'app-plan-task-schedule',
  standalone: true,
  imports: [CommonModule, RouterLink, TaskScheduleTimelineComponent, TranslateModule],
  providers: [...PLAN_TASK_SCHEDULE_PROVIDERS],
  template: `
    <main class="page-main page-main--fit">
      <section class="page">
        <a [routerLink]="['/plans', planId]">{{ 'plans.task_schedule.back_to_plan' | translate }}</a>
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error" role="alert">
            <p>{{ control.error | translate }}</p>
          </div>
        } @else if (control.schedule) {
          <h2>{{ 'plans.task_schedule.title' | translate: { name: control.schedule.plan.name } }}</h2>
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
    this.load(planId);
  }

  load(planId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ planId });
  }
}
