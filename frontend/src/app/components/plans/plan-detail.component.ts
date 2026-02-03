import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { GanttChartComponent } from './gantt-chart.component';
import { PlanFieldClimateComponent } from './plan-field-climate.component';
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
  imports: [CommonModule, RouterLink, GanttChartComponent, PlanFieldClimateComponent, TranslateModule],
  providers: [
    PlanDetailPresenter,
    LoadPlanDetailUseCase,
    { provide: LOAD_PLAN_DETAIL_OUTPUT_PORT, useExisting: PlanDetailPresenter },
    { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
  ],
  template: `
    <section class="page">
      <a [routerLink]="['/plans']">{{ 'plans.show.back_to_list' | translate }}</a>
      @if (control.loading) {
        <p>{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else if (control.plan) {
        <h2>{{ control.plan.name }}</h2>
        @if (control.planData) {
          <div class="plan-detail__layout">
            <div class="plan-detail__pane plan-detail__gantt">
              <app-gantt-chart
                [data]="control.planData"
                [planType]="planType"
                (cultivationSelected)="handleCultivationSelection($event)"
              />
            </div>

            <div
              class="plan-detail__pane plan-detail__climate-panel"
              [class.plan-detail__climate-panel--open]="selectedCultivationId !== null"
            >
              @if (selectedCultivationId) {
                <app-plan-field-climate
                  [fieldCultivationId]="selectedCultivationId"
                  [planType]="selectedPlanType"
                  (close)="closeClimatePanel()"
                />
              } @else {
                <p class="plan-detail__climate-placeholder">
                  {{ 'plans.detail.select_cultivation_hint' | translate }}
                </p>
              }
            </div>
          </div>

        }
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
  private readonly translate = inject(TranslateService);

  private _control: PlanDetailViewState = initialControl;
  get control(): PlanDetailViewState {
    return this._control;
  }
  set control(value: PlanDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  readonly planType: 'private' | 'public' = 'private';
  selectedCultivationId: number | null = null;
  selectedPlanType: 'private' | 'public' = this.planType;

  ngOnInit(): void {
    this.presenter.setView(this);
    const planId = Number(this.route.snapshot.paramMap.get('id'));
    if (!planId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: this.translate.instant('plans.errors.invalid_id')
      };
      return;
    }
    this.load(planId);
  }

  load(planId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ planId });
  }

  handleCultivationSelection(event: { cultivationId: number; planType: 'private' | 'public' }): void {
    const alreadySelected =
      this.selectedCultivationId === event.cultivationId &&
      this.selectedPlanType === event.planType;

    if (alreadySelected) {
      this.closeClimatePanel();
      return;
    }

    this.selectedCultivationId = event.cultivationId;
    this.selectedPlanType = event.planType;
  }

  closeClimatePanel(): void {
    this.selectedCultivationId = null;
    this.selectedPlanType = this.planType;
  }
}
