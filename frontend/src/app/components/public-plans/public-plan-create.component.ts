import { Component, OnInit, inject, ChangeDetectorRef, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { PublicPlanCreateView, PublicPlanCreateViewState } from './public-plan-create.view';
import { LoadPublicPlanFarmsUseCase } from '../../usecase/public-plans/load-public-plan-farms.usecase';
import { ResetPublicPlanCreationStateUseCase } from '../../usecase/public-plans/reset-public-plan-creation-state.usecase';
import {
  PublicPlanCreatePresenter,
  PUBLIC_PLAN_CREATE_PROVIDERS
} from '../../usecase/public-plans/public-plan-create.providers';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { Farm } from '../../domain/farms/farm';
import { resolveReferenceFarmRegion } from '../../core/browser-region';
import { applyAppLang, mapFarmRegionToAppLang } from '../../core/app-locale';
import { localizePublicPlanReferenceFarmName } from '../../core/public-plan-reference-farm-name';
import { PublicPlanContextHeaderComponent } from './public-plan-context-header.component';
import { MasterContextCrumb } from '../masters/master-context-header/master-context-crumb';
const initialControl: PublicPlanCreateViewState = {
  loading: true,
  error: null,
  farms: []
};

@Component({
  selector: 'app-public-plan-create',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.Default,
  imports: [CommonModule, FormsModule, TranslateModule, PublicPlanContextHeaderComponent],
  providers: [...PUBLIC_PLAN_CREATE_PROVIDERS],
  template: `
    <main class="page-main public-plans-wrapper">
      <h1 class="visually-hidden">{{ 'public_plans.title' | translate }}</h1>
      <div class="free-plans-container">
        <app-public-plan-context-header [crumbs]="contextCrumbs" />
        <div class="compact-header-card">
          <div class="compact-header-title">
            <span class="title-icon" aria-hidden="true">🌱</span>
            <span class="title-text">{{ 'public_plans.title' | translate }}</span>
          </div>
          <div class="compact-progress">
            <div class="compact-step active">
              <div class="step-number">1</div>
              <span class="step-label">{{ 'public_plans.steps.region' | translate }}</span>
            </div>
            <div class="compact-step-divider"></div>
            <div class="compact-step">
              <div class="step-number">2</div>
              <span class="step-label">{{ 'public_plans.steps.crop' | translate }}</span>
            </div>
          </div>
        </div>

        <section class="content-card" aria-labelledby="create-heading">
          <h2 id="create-heading" class="visually-hidden">{{ 'public_plans.select_farm.available_farms' | translate }}</h2>
          @if (control.loading) {
            <div class="loading-state">
              <p>{{ 'common.loading' | translate }}</p>
            </div>
          } @else if (control.error) {
            <p class="error-message">{{ control.error }}</p>
          } @else {
            <section class="selection-section mt-6" aria-labelledby="farm-heading">
              <h3 id="farm-heading">{{ 'public_plans.select_farm.available_farms' | translate }}</h3>
              <div class="enhanced-grid">
                @for (farm of control.farms; track farm.id) {
                  <div
                    class="enhanced-selection-card"
                    [class.active]="selectedFarmId === farm.id"
                    (click)="selectFarm(farm)"
                    (keydown.enter)="selectFarm(farm)"
                    (keydown.space)="selectFarm(farm); $event.preventDefault()"
                    tabindex="0"
                    role="button"
                  >
                    <div class="enhanced-card-icon">🌏</div>
                    <div class="enhanced-card-title">{{ displayFarmName(farm) }}</div>
                    <!-- region subtitle intentionally removed: region is auto-detected and not shown to user -->
                  </div>
                }
              </div>
            </section>
          }
        </section>
      </div>
    </main>
  `,
  // Use shared public-plan stylesheet
  styleUrls: ['./public-plan.component.css']
})
export class PublicPlanCreateComponent implements PublicPlanCreateView, OnInit {
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadPublicPlanFarmsUseCase);
  private readonly resetStateUseCase = inject(ResetPublicPlanCreationStateUseCase);
  private readonly presenter = inject(PublicPlanCreatePresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);

  selectedFarmId: number | null = null;
  selectedFarm: Farm | null = null;

  get contextCrumbs(): MasterContextCrumb[] {
    return [{ labelKey: 'public_plans.breadcrumb_root' }];
  }

  // Note: region selection UI removed. Region is auto-detected and not exposed to the user.

  private _control: PublicPlanCreateViewState = initialControl;
  get control(): PublicPlanCreateViewState {
    return this._control;
  }
  set control(value: PublicPlanCreateViewState) {
    this._control = value;
    this.cdr.detectChanges();
  }

  ngOnInit(): void {
    const cropSlug = this.route.snapshot.queryParamMap.get('crop');
    // Reset state to ensure clean state for new plan creation
    this.resetStateUseCase.execute({});
    if (cropSlug) {
      this.publicPlanStore.setPendingCropSlug(cropSlug);
    }
    this.presenter.setView(this);
    const state = this.publicPlanStore.state;
    if (state.farm) {
      this.selectedFarmId = state.farm.id;
      this.selectedFarm = state.farm;
      // Load farms to allow re-selection and avoid stuck loading
      this.loadFarms(state.farm.region ?? resolveReferenceFarmRegion(
        this.translate.currentLang || this.translate.defaultLang
      ));
    } else {
      const region = resolveReferenceFarmRegion(
        this.translate.currentLang || this.translate.defaultLang
      );
      this.loadFarms(region);
    }
  }

  selectFarm(farm: Farm): void {
    const lang = mapFarmRegionToAppLang(farm.region);
    if (lang) {
      applyAppLang(this.translate, lang, { persist: false });
    }
    this.selectedFarmId = farm.id;
    this.selectedFarm = farm;
    this.publicPlanStore.setFarm(farm);
    this.router.navigate(['/public-plans/select-crop']);
  }

  displayFarmName(farm: Farm): string {
    return localizePublicPlanReferenceFarmName(farm, (key) => this.translate.instant(key));
  }

  private loadFarms(region: string): void {
    this.control = {
      ...this.control,
      loading: true,
      error: null,
      farms: []
    };
    this.useCase.execute({ region });
  }
}
