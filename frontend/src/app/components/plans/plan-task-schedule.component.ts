import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TaskScheduleTimelineComponent } from './task-schedule-timeline.component';
import { PlanTaskScheduleView, PlanTaskScheduleViewState } from './plan-task-schedule.view';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { PlanTaskSchedulePresenter } from '../../adapters/plans/plan-task-schedule.presenter';
import { LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT } from '../../usecase/plans/load-plan-task-schedule.output-port';
import { PLAN_GATEWAY } from '../../usecase/plans/plan-gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';

const initialControl: PlanTaskScheduleViewState = {
  loading: true,
  error: null,
  schedule: null
};

@Component({
  selector: 'app-plan-task-schedule',
  standalone: true,
  imports: [CommonModule, RouterLink, TaskScheduleTimelineComponent],
  providers: [
    PlanTaskSchedulePresenter,
    LoadPlanTaskScheduleUseCase,
    { provide: LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT, useExisting: PlanTaskSchedulePresenter },
    { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
  ],
  template: `
    <section class="page">
      <a [routerLink]="['/plans', planId]">Back to plan</a>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else if (control.schedule) {
        <h2>Task Schedule: {{ control.schedule.plan.name }}</h2>
        <app-task-schedule-timeline [fields]="control.schedule.fields" />
      }
    </section>
  `,
  styleUrl: './plan-task-schedule.component.css'
})
export class PlanTaskScheduleComponent implements PlanTaskScheduleView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadPlanTaskScheduleUseCase);
  private readonly presenter = inject(PlanTaskSchedulePresenter);

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  private _control: PlanTaskScheduleViewState = initialControl;
  get control(): PlanTaskScheduleViewState {
    return this._control;
  }
  set control(value: PlanTaskScheduleViewState) {
    this._control = value;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const planId = this.planId;
    if (!planId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid plan id.' };
      return;
    }
    this.load(planId);
  }

  load(planId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ planId });
  }
}
