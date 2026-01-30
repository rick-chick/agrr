import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PublicPlanResultsView, PublicPlanResultsViewState } from './public-plan-results.view';
import { LoadPublicPlanResultsUseCase } from '../../usecase/public-plans/load-public-plan-results.usecase';
import { PublicPlanResultsPresenter } from '../../adapters/public-plans/public-plan-results.presenter';
import { LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT } from '../../usecase/public-plans/load-public-plan-results.output-port';
import { PLAN_GATEWAY } from '../../usecase/plans/plan-gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { GanttChartComponent } from '../plans/gantt-chart.component';
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
  imports: [CommonModule, GanttChartComponent, TranslateModule, RouterLink],
  providers: [
    PublicPlanResultsPresenter,
    LoadPublicPlanResultsUseCase,
    { provide: LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT, useClass: PublicPlanResultsPresenter },
    { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
  ],
  template: `
    <div class="public-plans-wrapper">
      <div class="cultivation-results-container">
        @if (control.loading) {
          <div class="loading-state">
            <p>{{ 'public_plans.results.loading_data' | translate }}</p>
          </div>
        } @else if (control.error) {
          <p class="error-message">{{ control.error }}</p>
        } @else if (control.data) {
          <div class="compact-header-card success">
            <div class="compact-header-title">
              <span class="title-icon">📊</span>
              <span class="title-text">{{ 'public_plans.results.header.title' | translate }}</span>
              <span class="status-badge completed">{{ 'public_plans.results.header.badge' | translate }}</span>
            </div>
            <div class="compact-subtitle">
              {{ farm?.name }} · {{ 'public_plans.results.header.field_count_value' | translate: { count: control.data.data.fields.length } }}
            </div>
          </div>

          <div class="enhanced-summary-card">
            <div class="enhanced-summary-items">
              <div class="enhanced-summary-row">
                <div class="enhanced-summary-icon">💰</div>
                <div class="enhanced-summary-content">
                  <div class="enhanced-summary-label">{{ 'public_plans.results.header.total_profit' | translate }}</div>
                  <div class="enhanced-summary-value">¥{{ control.data.total_profit | number }}</div>
                </div>
              </div>
              <div class="enhanced-summary-row">
                <div class="enhanced-summary-icon">📉</div>
                <div class="enhanced-summary-content">
                  <div class="enhanced-summary-label">{{ 'public_plans.results.header.total_cost' | translate }}</div>
                  <div class="enhanced-summary-value">¥{{ control.data.total_cost | number }}</div>
                </div>
              </div>
            </div>
          </div>

          <app-gantt-chart [data]="control.data" />

          <div class="action-buttons">
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
        }
      </div>
    </div>
  `,
  styleUrl: './public-plan.component.css'
})
export class PublicPlanResultsComponent implements PublicPlanResultsView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadPublicPlanResultsUseCase);
  private readonly presenter = inject(PublicPlanResultsPresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);

  protected readonly auth = inject(AuthService);

  get farm() {
    return this.publicPlanStore.state.farm;
  }

  private _control: PublicPlanResultsViewState = initialControl;
  get control(): PublicPlanResultsViewState {
    return this._control;
  }
  set control(value: PublicPlanResultsViewState) {
    this._control = value;
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
    console.log('Saving plan...');
  }
}
