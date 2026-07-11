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
import { GANTT_CHART_API_PROVIDERS } from '../../usecase/plans/gantt-chart.providers';
import { PLAN_FIELD_CLIMATE_API_PROVIDERS } from '../../usecase/plans/plan-field-climate.providers';
import { PlanGanttClimateShellComponent } from '../plans/plan-gantt-climate-shell.component';
import { AuthService } from '../../services/auth.service';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { FlashMessageService } from '../../services/flash-message.service';
import {
  consumePendingPublicPlanSave,
  setPendingPublicPlanSave
} from '../../services/public-plans/pending-public-plan-save';
import { applyAppLang, mapFarmRegionToAppLang } from '../../core/app-locale';
import { applyPendingFlashAndNavigationViewEffects } from '../../core/view-effects/pending-success-flash-view.effects';
import { PublicPlanContextHeaderComponent } from './public-plan-context-header.component';
import { MasterContextCrumb } from '../masters/master-context-header/master-context-crumb';

const initialControl: PublicPlanResultsViewState = {
  loading: true,
  error: null,
  data: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  pendingNavigation: null
};

@Component({
  selector: 'app-public-plan-results',
  standalone: true,
  imports: [CommonModule, PlanGanttClimateShellComponent, TranslateModule, RouterLink, PublicPlanContextHeaderComponent],
  providers: [
    ...PUBLIC_PLAN_RESULTS_PROVIDERS,
    ...GANTT_CHART_API_PROVIDERS,
    ...PLAN_FIELD_CLIMATE_API_PROVIDERS
  ],
  template: `
    <main class="page-main public-plans-wrapper">
      <h1 class="visually-hidden">{{ 'public_plans.title' | translate }}</h1>
      <div class="free-plans-container">
        <app-public-plan-context-header [crumbs]="contextCrumbs" />
        @if (control.loading) {
          <div class="loading-state">
            <p>{{ 'public_plans.results.loading_data' | translate }}</p>
          </div>
        } @else if (control.error) {
          <p class="error-message">{{ control.error | translate }}</p>
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

          <div class="public-plan-results__body plan-detail-surface">
            <app-plan-gantt-climate-shell [data]="control.data" [planType]="planType" />
          </div>
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

  get contextCrumbs(): MasterContextCrumb[] {
    return [
      { labelKey: 'public_plans.breadcrumb_root', routerLink: ['/public-plans/new'] },
      { labelKey: 'public_plans.results.breadcrumb' }
    ];
  }

  private pendingSaveTriggered = false;

  private _control: PublicPlanResultsViewState = initialControl;
  get control(): PublicPlanResultsViewState {
    return this._control;
  }
  set control(value: PublicPlanResultsViewState) {
    this._control = applyPendingFlashAndNavigationViewEffects(value, {
      flash: this.flashMessage,
      router: this.router
    });
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const lang = mapFarmRegionToAppLang(this.publicPlanStore.state.farm?.region);
    if (lang) {
      applyAppLang(this.translate, lang, { persist: false });
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
}
