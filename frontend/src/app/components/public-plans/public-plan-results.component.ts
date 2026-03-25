import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PublicPlanResultsView, PublicPlanResultsViewState } from './public-plan-results.view';
import { LoadPublicPlanResultsUseCase } from '../../usecase/public-plans/load-public-plan-results.usecase';
import { SavePublicPlanUseCase } from '../../usecase/public-plans/save-public-plan.usecase';
import { PublicPlanResultsPresenter } from '../../adapters/public-plans/public-plan-results.presenter';
import { LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT } from '../../usecase/public-plans/load-public-plan-results.output-port';
import { SAVE_PUBLIC_PLAN_OUTPUT_PORT } from '../../usecase/public-plans/save-public-plan.output-port';
import { PLAN_GATEWAY } from '../../usecase/plans/plan-gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PUBLIC_PLAN_GATEWAY } from '../../usecase/public-plans/public-plan-gateway';
import { PublicPlanApiGateway } from '../../adapters/public-plans/public-plan-api.gateway';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { GanttChartComponent } from '../plans/gantt-chart.component';
import { PlanFieldClimateComponent } from '../plans/plan-field-climate.component';
import { AuthService } from '../../services/auth.service';
import { getApiBaseUrl } from '../../core/api-base-url';

const initialControl: PublicPlanResultsViewState = {
  loading: true,
  error: null,
  data: null
};

@Component({
  selector: 'app-public-plan-results',
  standalone: true,
  imports: [CommonModule, GanttChartComponent, PlanFieldClimateComponent, TranslateModule, RouterLink],
  providers: [
    PublicPlanResultsPresenter,
    LoadPublicPlanResultsUseCase,
    SavePublicPlanUseCase,
    { provide: LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT, useExisting: PublicPlanResultsPresenter },
    { provide: SAVE_PUBLIC_PLAN_OUTPUT_PORT, useExisting: PublicPlanResultsPresenter },
    { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
    { provide: PUBLIC_PLAN_GATEWAY, useClass: PublicPlanApiGateway }
  ],
  template: `
    <main class="page-main public-plans-wrapper">
      <h1 class="visually-hidden">{{ 'public_plans.title' | translate }}</h1>
      <div class="free-plans-container">
        @if (control.loading) {
          <div class="loading-state">
            <p>{{ 'public_plans.results.loading_data' | translate }}</p>
          </div>
        } @else if (control.error) {
          <p class="error-message">{{ control.error }}</p>
        } @else if (control.data) {
          <div class="gantt-results-header">
            <div class="gantt-results-header-main">
              <div class="gantt-results-header-icon" aria-hidden="true">🎉</div>
              <h2 class="gantt-results-header-title">{{ 'public_plans.results.header.title' | translate }}</h2>
              <div class="gantt-results-header-badge">{{ 'public_plans.results.header.badge' | translate }}</div>
            </div>

            <div class="gantt-results-header-summary">
              <div class="gantt-summary-item">
                <span class="gantt-summary-icon" aria-hidden="true">🌍</span>
                <span class="gantt-summary-label">{{ 'public_plans.results.header.region' | translate }}</span>
                <span class="gantt-summary-value">{{ farm?.name }}</span>
              </div>
              <div class="gantt-summary-item">
                <span class="gantt-summary-icon" aria-hidden="true">📏</span>
                <span class="gantt-summary-label">{{ 'public_plans.results.header.total_area' | translate }}</span>
                <span class="gantt-summary-value">{{ control.data.data.total_area | number }}㎡</span>
              </div>
              <div class="gantt-summary-item">
                <span class="gantt-summary-icon" aria-hidden="true">🏞️</span>
                <span class="gantt-summary-label">{{ 'public_plans.results.header.field_count' | translate }}</span>
                <span class="gantt-summary-value">{{
                  'public_plans.results.header.field_count_value' | translate: { count: resultsFieldCount }
                }}</span>
              </div>
              <div class="gantt-summary-item">
                <span class="gantt-summary-icon" aria-hidden="true">💰</span>
                <span class="gantt-summary-label">{{ 'public_plans.results.header.total_cost' | translate }}</span>
                <span class="gantt-summary-value">¥{{ resultsTotalCost | number }}</span>
              </div>
              @if (resultsHasRevenue) {
                <div class="gantt-summary-item">
                  <span class="gantt-summary-icon" aria-hidden="true">📈</span>
                  <span class="gantt-summary-label">{{ 'public_plans.results.header.total_revenue' | translate }}</span>
                  <span class="gantt-summary-value">¥{{ resultsTotalRevenue | number }}</span>
                </div>
                <div class="gantt-summary-item">
                  <span class="gantt-summary-icon" aria-hidden="true">💎</span>
                  <span class="gantt-summary-label">{{ 'public_plans.results.header.total_profit' | translate }}</span>
                  <span class="gantt-summary-value">¥{{ resultsTotalProfit | number }}</span>
                </div>
              }
            </div>

            <div class="gantt-results-header-subtitle">
              {{ 'public_plans.results.header.subtitle' | translate: { count: resultsSubtitleFieldCount } }}
            </div>

            @if (rangeLabelText) {
              <div class="gantt-visible-range">
                <span class="gantt-visible-range__value">{{ rangeLabelText }}</span>
              </div>
            }
          </div>

          <div class="public-plan-results__header-actions">
            <button type="button" class="btn btn-primary" (click)="savePlan()">
              {{ 'public_plans.save.button' | translate }}
            </button>

            @if (auth.user()) {
              <a [routerLink]="['/plans']" class="btn btn-white">
                {{ 'public_plans.results.view_my_plans' | translate }}
              </a>
            }

            <a [routerLink]="['/public-plans/new']" class="btn btn-white">
              {{ 'public_plans.results.create_new_plan' | translate }}
            </a>
          </div>

          <section class="page">
            <div class="plan-detail__layout">
              <div class="plan-detail__pane plan-detail__gantt">
                <app-gantt-chart
                  [data]="control.data"
                  [planType]="planType"
                  (cultivationSelected)="handleCultivationSelection($event)"
                (visibleRangeChange)="handleVisibleRangeUpdate($event)"
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
                    Select a cultivation bar to show climate insights.
                  </p>
                }
              </div>
            </div>
          </section>
        }
      </div>
    </main>
  `,
  styleUrls: ['./public-plan-results.component.css', './public-plan.component.css']
})
export class PublicPlanResultsComponent implements PublicPlanResultsView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadPublicPlanResultsUseCase);
  private readonly saveUseCase = inject(SavePublicPlanUseCase);
  private readonly presenter = inject(PublicPlanResultsPresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly cdr = inject(ChangeDetectorRef);

  protected readonly auth = inject(AuthService);

  readonly planType: 'private' | 'public' = 'public';
  selectedCultivationId: number | null = null;
  selectedPlanType: 'private' | 'public' = this.planType;
  visibleRangeLabel = '';
  defaultVisibleRangeLabel = '';

  get rangeLabelText(): string {
    return this.visibleRangeLabel || this.defaultVisibleRangeLabel;
  }

  get farm() {
    return this.publicPlanStore.state.farm;
  }

  /** Rails `field_cultivations.count` に相当（圃場数表示・サブタイトル用） */
  get resultsFieldCount(): number {
    const inner = this.control.data?.data;
    if (!inner) {
      return 0;
    }
    return inner.fields?.length ?? inner.cultivations?.length ?? 0;
  }

  get resultsSubtitleFieldCount(): number {
    return this.resultsFieldCount;
  }

  get resultsHasRevenue(): boolean {
    return this.control.data?.total_revenue != null;
  }

  get resultsTotalCost(): number {
    return this.control.data?.total_cost ?? 0;
  }

  get resultsTotalRevenue(): number {
    return this.control.data?.total_revenue ?? 0;
  }

  get resultsTotalProfit(): number {
    return this.control.data?.total_profit ?? 0;
  }

  private _control: PublicPlanResultsViewState = initialControl;
  get control(): PublicPlanResultsViewState {
    return this._control;
  }
  set control(value: PublicPlanResultsViewState) {
    this._control = value;
    this.cdr.markForCheck();
    this.updateDefaultVisibleRangeLabel();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const planId =
      Number(this.route.snapshot.queryParamMap.get('planId')) ||
      this.publicPlanStore.state.planId;
    if (!planId) {
      this.control = {
        ...this.control,
        loading: false,
        error: 'Missing planId.',
        data: null
      };
      return;
    }
    this.useCase.execute({ planId });
  }

  savePlan(): void {
    if (!this.auth.user()) {
      const apiBase = getApiBaseUrl() || window.location.origin;
      const returnTo = encodeURIComponent(window.location.href);
      window.location.href = `${apiBase}/auth/login?return_to=${returnTo}`;
      return;
    }
    // Call save API if logged in
    const planId = Number(this.route.snapshot.queryParamMap.get('planId')) || this.publicPlanStore.state.planId;
    if (planId) {
      this.saveUseCase.execute({ planId });
    }
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

  handleVisibleRangeUpdate(range: { startDate: Date; endDate: Date; label: string }): void {
    this.visibleRangeLabel = range.label;
  }

  private updateDefaultVisibleRangeLabel(): void {
    this.visibleRangeLabel = '';
    if (!this.control.data?.data) {
      this.defaultVisibleRangeLabel = '';
      return;
    }

    const start = this.control.data.data.planning_start_date;
    const end = this.control.data.data.planning_end_date;
    if (!start || !end) {
      this.defaultVisibleRangeLabel = '';
      return;
    }

    this.defaultVisibleRangeLabel = this.formatRangeLabel(start, end);
  }

  private formatRangeLabel(startIso: string, endIso: string): string {
    const format = (value: string) => {
      const date = new Date(value);
      const year = date.getFullYear();
      const month = (date.getMonth() + 1).toString().padStart(2, '0');
      return `${year}/${month}`;
    };
    return `${format(startIso)}～${format(endIso)}`;
  }
}
