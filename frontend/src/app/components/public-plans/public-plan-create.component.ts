import { Component, OnInit, inject, ChangeDetectorRef, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { PublicPlanCreateView, PublicPlanCreateViewState } from './public-plan-create.view';
import { LoadPublicPlanFarmsUseCase } from '../../usecase/public-plans/load-public-plan-farms.usecase';
import { PublicPlanCreatePresenter } from '../../adapters/public-plans/public-plan-create.presenter';
import { LOAD_PUBLIC_PLAN_FARMS_OUTPUT_PORT } from '../../usecase/public-plans/load-public-plan-farms.output-port';
import { PUBLIC_PLAN_GATEWAY } from '../../usecase/public-plans/public-plan-gateway';
import { PublicPlanApiGateway } from '../../adapters/public-plans/public-plan-api.gateway';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { Farm } from '../../domain/farms/farm';

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
  providers: [
    PublicPlanCreatePresenter,
    LoadPublicPlanFarmsUseCase,
    { provide: LOAD_PUBLIC_PLAN_FARMS_OUTPUT_PORT, useExisting: PublicPlanCreatePresenter },
    { provide: PUBLIC_PLAN_GATEWAY, useClass: PublicPlanApiGateway }
  ],
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
              <span class="step-label">{{ 'public_plans.steps.size' | translate }}</span>
            </div>
            <div class="compact-step-divider"></div>
            <div class="compact-step">
              <div class="step-number">3</div>
              <span class="step-label">{{ 'public_plans.steps.crop' | translate }}</span>
            </div>
          </div>
        </div>

        @if (!selectedRegion) {
          <section class="content-card" aria-labelledby="region-heading">
            <h2 id="region-heading">{{ 'public_plans.region_selection.title' | translate }}</h2>
            <p class="mb-4">{{ 'public_plans.region_selection.subtitle' | translate }}</p>
            <div class="enhanced-grid">
              @for (region of availableRegions; track region.id) {
                <div
                  class="enhanced-selection-card"
                  [class.active]="selectedRegionId === region.id"
                  (click)="selectRegion(region)"
                  (keydown.enter)="selectRegion(region)"
                  (keydown.space)="selectRegion(region); $event.preventDefault()"
                  tabindex="0"
                  role="button"
                >
                  <div class="enhanced-card-icon">{{ region.icon }}</div>
                  <div class="enhanced-card-title">{{ region.name | translate }}</div>
                  <div class="enhanced-card-subtitle">{{ region.description | translate }}</div>
                </div>
              }
            </div>
          </section>
        } @else {
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
                      <div class="enhanced-card-subtitle">{{ farm.region }}</div>
                    </div>
                  }
                </div>
              </section>
            }
          </section>
        }
      </div>
    </main>
  `,
  styleUrl: './public-plan.component.css'
})
export class PublicPlanCreateComponent implements PublicPlanCreateView, OnInit {
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadPublicPlanFarmsUseCase);
  private readonly presenter = inject(PublicPlanCreatePresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);

  selectedFarmId: number | null = null;
  selectedFarm: Farm | null = null;
  selectedRegionId: string | null = null;
  selectedRegion: { id: string; name: string; description: string; icon: string } | null = null;

  availableRegions = [
    { id: 'jp', name: 'public_plans.regions.jp.name', description: 'public_plans.regions.jp.description', icon: '🇯🇵' },
    { id: 'us', name: 'public_plans.regions.us.name', description: 'public_plans.regions.us.description', icon: '🇺🇸' },
    { id: 'in', name: 'public_plans.regions.in.name', description: 'public_plans.regions.in.description', icon: '🇮🇳' }
  ];

  private _control: PublicPlanCreateViewState = initialControl;
  get control(): PublicPlanCreateViewState {
    return this._control;
  }
  set control(value: PublicPlanCreateViewState) {
    this._control = value;
    this.cdr.detectChanges();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const state = this.publicPlanStore.state;
    if (state.farm) {
      this.selectedFarmId = state.farm.id;
      this.selectedFarm = state.farm;
      // If farm is already selected, find the corresponding region
      this.selectedRegion = this.availableRegions.find(r => r.id === state.farm?.region) || null;
      this.selectedRegionId = this.selectedRegion?.id || null;
      // Don't load farms again if we already have a farm
    } else {
      // Reset region selection if no farm is selected
      this.selectedRegion = null;
      this.selectedRegionId = null;
    }
  }

  selectRegion(region: { id: string; name: string; description: string; icon: string }): void {
    this.selectedRegionId = region.id;
    this.selectedRegion = region;
    this.loadFarms(region.id);
  }

  selectFarm(farm: Farm): void {
    this.selectedFarmId = farm.id;
    this.selectedFarm = farm;
    this.publicPlanStore.setFarm(farm);
    this.router.navigate(['/public-plans/select-farm-size']);
  }

  private loadFarms(region: string): void {
    console.log('🌱 [PublicPlanCreateComponent] loadFarms called with region:', region);
    console.log('🌱 [PublicPlanCreateComponent] current control state:', this.control);
    this.useCase.execute({ region });
  }
}
