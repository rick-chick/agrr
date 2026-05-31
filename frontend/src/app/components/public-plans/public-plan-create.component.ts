import { Component, OnInit, inject, ChangeDetectorRef, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
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
import { DEFAULT_PUBLIC_PLAN_FARM_SIZE } from '../../domain/public-plans/default-public-plan-farm-size';

const initialControl: PublicPlanCreateViewState = {
  loading: true,
  error: null,
  farms: [],
  farmSizes: []
};

@Component({
  selector: 'app-public-plan-create',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.Default,
  imports: [CommonModule, FormsModule, TranslateModule],
  providers: [...PUBLIC_PLAN_CREATE_PROVIDERS],
  template: `
    <main class="page-main public-plans-wrapper">
      <h1 class="visually-hidden">{{ 'public_plans.title' | translate }}</h1>
      <div class="free-plans-container">
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
                    <div class="enhanced-card-title">{{ farm.name }}</div>
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
  private readonly useCase = inject(LoadPublicPlanFarmsUseCase);
  private readonly resetStateUseCase = inject(ResetPublicPlanCreationStateUseCase);
  private readonly presenter = inject(PublicPlanCreatePresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);

  selectedFarmId: number | null = null;
  selectedFarm: Farm | null = null;
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
    // Reset state to ensure clean state for new plan creation
    this.resetStateUseCase.execute({});
    this.presenter.setView(this);
    const state = this.publicPlanStore.state;
    if (state.farm) {
      this.selectedFarmId = state.farm.id;
      this.selectedFarm = state.farm;
      // Load farms to allow re-selection and avoid stuck loading
      this.loadFarms(state.farm.region);
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
      applyAppLang(this.translate, lang);
    }
    this.selectedFarmId = farm.id;
    this.selectedFarm = farm;
    this.publicPlanStore.setFarm(farm);
    this.publicPlanStore.setFarmSize(DEFAULT_PUBLIC_PLAN_FARM_SIZE);
    this.router.navigate(['/public-plans/select-crop']);
  }

  private loadFarms(region: string): void {
    this.control = {
      ...this.control,
      loading: true,
      error: null,
      farms: [],
      farmSizes: []
    };
    this.useCase.execute({ region });
  }
}
