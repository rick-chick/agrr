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
            <div class="compact-summary-line">
              <span class="compact-icon">🎉</span>
              <span class="compact-text">{{ 'public_plans.results.header.title' | translate }}</span>
              <span class="compact-separator">•</span>
              <span class="compact-icon">🌍</span>
              <span class="compact-value">{{ farm?.name }}</span>
              <span class="compact-separator">•</span>
              <span class="compact-icon">📏</span>
              <span class="compact-value">{{ control.data.data.total_area | number }}㎡</span>
            </div>
          </div>

          <app-gantt-chart [data]="control.data" planType="public" />

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
    </main>
  `,
  styleUrls: ['./public-plan.component.css']
})
export class PublicPlanResultsComponent implements PublicPlanResultsView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadPublicPlanResultsUseCase);
  private readonly saveUseCase = inject(SavePublicPlanUseCase);
  private readonly presenter = inject(PublicPlanResultsPresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly cdr = inject(ChangeDetectorRef);

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
    this.cdr.markForCheck();
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
}
