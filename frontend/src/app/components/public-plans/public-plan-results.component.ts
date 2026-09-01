import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { Subscription, take } from 'rxjs';
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
  peekPendingPublicPlanSave,
  setPendingPublicPlanSave
} from '../../services/public-plans/pending-public-plan-save';
import { applyAppLang, mapFarmRegionToAppLang } from '../../core/app-locale';
import { applyPendingFlashAndNavigationViewEffects } from '../../core/view-effects/pending-success-flash-view.effects';
import { AppSeoMetaService } from '../../core/seo/app-seo-meta.service';
import type { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PublicPlanContextHeaderComponent } from './public-plan-context-header.component';
import { MasterContextCrumb } from '../masters/master-context-header/master-context-crumb';
import { PublicPlanPrivateValuePreviewComponent } from './public-plan-private-value-preview.component';
import { PublicPlanResultsNextStepsComponent } from './public-plan-results-next-steps.component';

const initialControl: PublicPlanResultsViewState = {
  loading: true,
  error: null,
  data: null,
  savedPrivatePlanId: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  pendingNavigation: null
};

@Component({
  selector: 'app-public-plan-results',
  standalone: true,
  imports: [
    CommonModule,
    PlanGanttClimateShellComponent,
    TranslateModule,
    RouterLink,
    PublicPlanContextHeaderComponent,
    PublicPlanPrivateValuePreviewComponent,
    PublicPlanResultsNextStepsComponent
  ],
  providers: [
    ...PUBLIC_PLAN_RESULTS_PROVIDERS,
    ...GANTT_CHART_API_PROVIDERS,
    ...PLAN_FIELD_CLIMATE_API_PROVIDERS
  ],
  template: `
    <div class="page-main public-plans-wrapper">
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
          <div class="public-plan-results__body plan-detail-surface">
            <app-plan-gantt-climate-shell [data]="control.data" [planType]="planType">
              @if (auth.user()) {
                <div ganttActionPrefix class="public-plan-results__gantt-prefix">
                  <a [routerLink]="['/plans']" class="btn btn-white">
                    {{ 'public_plans.results.view_my_plans' | translate }}
                  </a>
                </div>
              }
            </app-plan-gantt-climate-shell>
          </div>

          <app-public-plan-results-next-steps
            [isLoggedIn]="auth.user() !== null"
            [savedPrivatePlanId]="control.savedPrivatePlanId"
            [loginReturnTo]="loginReturnTo"
            (saveRequest)="savePlan()"
          />

          <app-public-plan-private-value-preview />
        }
      </div>
    </div>
  `,
  styleUrls: ['./public-plan-results.component.css', './public-plan.component.css']
})
export class PublicPlanResultsComponent implements PublicPlanResultsView, OnInit, OnDestroy {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadPublicPlanResultsUseCase);
  private readonly saveUseCase = inject(SavePublicPlanUseCase);
  private readonly presenter = inject(PublicPlanResultsPresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly translate = inject(TranslateService);
  private readonly seoMeta = inject(AppSeoMetaService);

  private langChangeSubscription?: Subscription;
  private seoPlanId: number | null = null;
  private seoPlanData: CultivationPlanData | null = null;

  protected readonly auth = inject(AuthService);

  readonly planType: 'private' | 'public' = 'public';

  get loginReturnTo(): string {
    return typeof window !== 'undefined' ? window.location.href : '';
  }

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
    this.syncSeoFromControl(value);
    this.cdr.markForCheck();
  }

  ngOnDestroy(): void {
    this.langChangeSubscription?.unsubscribe();
  }

  private syncSeoFromControl(value: PublicPlanResultsViewState): void {
    const planId = this.resolvePlanId();
    if (value.data) {
      this.seoPlanId = planId;
      this.seoPlanData = value.data;
      this.seoMeta.refreshPublicPlanResultsMeta(planId, value.data);
      return;
    }
    if (!value.loading) {
      this.seoPlanId = planId > 0 ? planId : null;
      this.seoPlanData = null;
      this.seoMeta.refreshPublicPlanResultsMeta(this.seoPlanId, null);
    }
  }

  private syncSeoFromStoredState(): void {
    this.seoMeta.refreshPublicPlanResultsMeta(this.seoPlanId, this.seoPlanData);
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.langChangeSubscription = this.translate.onLangChange.subscribe(() => {
      this.syncSeoFromStoredState();
    });
    const lang = mapFarmRegionToAppLang(this.publicPlanStore.state.farm?.region);
    if (lang) {
      applyAppLang(this.translate, lang, { persist: false });
    }
    const planId = this.resolvePlanId();
    if (!planId) {
      this.seoMeta.refreshPublicPlanResultsMeta(null, null);
      this.control = {
        ...this.control,
        loading: false,
        error: 'public_plans.errors.restart',
        data: null
      };
      return;
    }
    this.useCase.execute({ planId });
    this.auth
      .loadCurrentUser()
      .pipe(take(1))
      .subscribe(() => this.maybeRunPendingSave());
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
      const stored = setPendingPublicPlanSave(planId);
      if (!stored) {
        this.flashMessage.show({
          type: 'error',
          text: this.translate.instant('public_plans.errors.storage_unavailable')
        });
        return;
      }
      void this.router.navigate(['/login'], {
        queryParams: { return_to: window.location.href }
      });
      return;
    }

    this.saveUseCase.execute({ planId });
  }

  private maybeRunPendingSave(): void {
    if (!this.auth.user() || this.pendingSaveTriggered) {
      return;
    }
    const pending = peekPendingPublicPlanSave();
    if (!pending) {
      return;
    }
    this.pendingSaveTriggered = true;
    this.saveUseCase.execute({ planId: pending.planId });
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
