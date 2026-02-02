import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { GanttChartComponent } from './gantt-chart.component';
import { PlanDetailView, PlanDetailViewState } from './plan-detail.view';
import { LoadPlanDetailUseCase } from '../../usecase/plans/load-plan-detail.usecase';
import { PlanDetailPresenter } from '../../adapters/plans/plan-detail.presenter';
import { LOAD_PLAN_DETAIL_OUTPUT_PORT } from '../../usecase/plans/load-plan-detail.output-port';
import { PLAN_GATEWAY } from '../../usecase/plans/plan-gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';

const initialControl: PlanDetailViewState = {
  loading: true,
  error: null,
  plan: null,
  planData: null
};

@Component({
  selector: 'app-plan-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, GanttChartComponent],
  providers: [
    PlanDetailPresenter,
    LoadPlanDetailUseCase,
    { provide: LOAD_PLAN_DETAIL_OUTPUT_PORT, useExisting: PlanDetailPresenter },
    { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
  ],
  template: `
    <section class="page">
      <a [routerLink]="['/plans']">Back to plans</a>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else if (control.plan) {
        <h2>{{ control.plan.name }}</h2>
        <p>Status: {{ control.plan.status ?? '-' }}</p>

        @if (control.planData) {
          <app-gantt-chart [data]="control.planData" planType="private" />
        }

        <div class="actions">
          <a [routerLink]="['/plans', control.plan.id, 'optimizing']">Optimizing</a>
          <a [routerLink]="['/plans', control.plan.id, 'task_schedule']">Task Schedule</a>
        </div>
      }
    </section>
  `,
  styleUrls: ['./plan-detail.component.css']
})
export class PlanDetailComponent implements PlanDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadPlanDetailUseCase);
  private readonly presenter = inject(PlanDetailPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PlanDetailViewState = initialControl;
  get control(): PlanDetailViewState {
    return this._control;
  }
  set control(value: PlanDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const planId = Number(this.route.snapshot.paramMap.get('id'));
    if (!planId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: 'Invalid plan id.'
      };
      return;
    }
    this.load(planId);
  }

  load(planId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ planId });
  }
}
