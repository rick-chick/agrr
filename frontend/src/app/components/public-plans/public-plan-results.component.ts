import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { take } from 'rxjs';
import { PublicPlanResultsView, PublicPlanResultsViewState } from './public-plan-results.view';
import { LoadPublicPlanResultsUseCase } from '../../usecase/public-plans/load-public-plan-results.usecase';
import { SavePublicPlanUseCase } from '../../usecase/public-plans/save-public-plan.usecase';
import {
  PublicPlanResultsPresenter,
  PUBLIC_PLAN_RESULTS_PROVIDERS
} from '../../usecase/public-plans/public-plan-results.providers';
import { GanttChartComponent } from '../plans/gantt-chart.component';
import { PlanFieldClimateComponent } from '../plans/plan-field-climate.component';
import { AuthService } from '../../services/auth.service';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { FlashMessageService } from '../../services/flash-message.service';
import {
  consumePendingPublicPlanSave,
  setPendingPublicPlanSave
} from '../../services/public-plans/pending-public-plan-save';
import { applyAppLang, mapFarmRegionToAppLang } from '../../core/app-locale';

/**
 * 無料計画の結果（/public-plans/results）。
 * Rails の `_header` 相当の `.gantt-results-header` サマリーは出さない（ガントと操作に寄せる）。
 * `ja.json` に残る `%{count}` は ngx-translate と非互換のため、Rails 用コピペで戻すと未置換表示になる。
 */
const initialControl: PublicPlanResultsViewState = {
  loading: true,
  error: null,
  data: null
};

@Component({
  selector: 'app-public-plan-results',
  standalone: true,
  imports: [CommonModule, GanttChartComponent, PlanFieldClimateComponent, TranslateModule, RouterLink],
  providers: [...PUBLIC_PLAN_RESULTS_PROVIDERS],
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
          <!-- 計画完成サマリー（.gantt-results-header）は意図的に非表示。ngx-translate は %{count} 非対応のため生表示になっていた。 -->

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
          </section>
        }
      </div>
    </main>
  `,
  styleUrls: ['./public-plan-results.component.css', './public-plan.component.css']
})
export class PublicPlanResultsComponent implements PublicPlanResultsView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadPublicPlanResultsUseCase);
  private readonly saveUseCase = inject(SavePublicPlanUseCase);
  private readonly presenter = inject(PublicPlanResultsPresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly translate = inject(TranslateService);

  protected readonly auth = inject(AuthService);

  readonly planType: 'private' | 'public' = 'public';
  selectedCultivationId: number | null = null;
  selectedPlanType: 'private' | 'public' = this.planType;

  private pendingSaveTriggered = false;

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
    const lang = mapFarmRegionToAppLang(this.publicPlanStore.state.farm?.region);
    if (lang) {
      applyAppLang(this.translate, lang);
    }
    const planId = this.resolvePlanId();
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
    this.auth
      .loadCurrentUser()
      .pipe(take(1))
      .subscribe(() => this.maybeRunPendingSave(planId));
  }

  savePlan(): void {
    const planId = this.resolvePlanId();
    if (!planId) {
      this.flashMessage.show({
        type: 'error',
        text: this.translate.instant('public_plans.errors.restart')
      });
      return;
    }

    if (!this.auth.user()) {
      setPendingPublicPlanSave(planId);
      void this.router.navigate(['/login'], {
        queryParams: { return_to: window.location.href }
      });
      return;
    }

    this.saveUseCase.execute({ planId });
  }

  private maybeRunPendingSave(fallbackPlanId: number): void {
    if (!this.auth.user() || this.pendingSaveTriggered) {
      return;
    }
    const pending = consumePendingPublicPlanSave();
    if (!pending) {
      return;
    }
    const planId =
      pending.planId === fallbackPlanId ? pending.planId : fallbackPlanId;
    this.pendingSaveTriggered = true;
    this.saveUseCase.execute({ planId });
  }

  private resolvePlanId(): number {
    const fromQuery = Number(this.route.snapshot.queryParamMap.get('planId'));
    if (!Number.isNaN(fromQuery) && fromQuery > 0) {
      return fromQuery;
    }
    const fromStore = this.publicPlanStore.state.planId;
    return fromStore && fromStore > 0 ? fromStore : 0;
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
