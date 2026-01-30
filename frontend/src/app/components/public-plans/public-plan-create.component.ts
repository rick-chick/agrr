import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PublicPlanCreateView, PublicPlanCreateViewState } from './public-plan-create.view';
import { LoadPublicPlanFarmsUseCase } from '../../usecase/public-plans/load-public-plan-farms.usecase';
import { PublicPlanCreatePresenter } from '../../adapters/public-plans/public-plan-create.presenter';
import { LOAD_PUBLIC_PLAN_FARMS_OUTPUT_PORT } from '../../usecase/public-plans/load-public-plan-farms.output-port';
import { PUBLIC_PLAN_GATEWAY } from '../../usecase/public-plans/public-plan-gateway';
import { PublicPlanApiGateway } from '../../adapters/public-plans/public-plan-api.gateway';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { Farm } from '../../domain/farms/farm';
import { FarmSizeOption } from '../../domain/public-plans/farm-size-option';

const initialControl: PublicPlanCreateViewState = {
  loading: true,
  error: null,
  farms: [],
  farmSizes: []
};

@Component({
  selector: 'app-public-plan-create',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
  providers: [
    PublicPlanCreatePresenter,
    LoadPublicPlanFarmsUseCase,
    { provide: LOAD_PUBLIC_PLAN_FARMS_OUTPUT_PORT, useClass: PublicPlanCreatePresenter },
    { provide: PUBLIC_PLAN_GATEWAY, useClass: PublicPlanApiGateway }
  ],
  template: `
    <div class="public-plans-wrapper">
      <div class="free-plans-container">
        <div class="compact-header-card">
          <div class="compact-header-title">
            <span class="title-icon">🌱</span>
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

        <div class="content-card">
          <h2 class="content-card-title">{{ 'public_plans.new.title' | translate }}</h2>
          <p class="content-card-subtitle">{{ 'public_plans.new.subtitle' | translate }}</p>

          <section class="selection-section">
            <h3>{{ 'public_plans.region_selection.title' | translate }}</h3>
            <div class="region-tabs">
              @for (region of regions; track region.value) {
                <button
                  type="button"
                  class="region-tab"
                  [class.active]="selectedRegion === region.value"
                  (click)="selectRegion(region.value)"
                >
                  <span class="region-flag">{{ region.flag }}</span>
                  <span class="region-name">{{ region.label }}</span>
                </button>
              }
            </div>
          </section>

          @if (control.loading) {
            <div class="loading-state">
              <p>{{ 'common.loading' | translate }}</p>
            </div>
          } @else if (control.error) {
            <p class="error-message">{{ control.error }}</p>
          } @else {
            <section class="selection-section mt-6">
              <h3>{{ 'public_plans.select_farm_size.summary.region' | translate }} ({{ 'public_plans.steps.region' | translate }})</h3>
              <div class="enhanced-grid">
                @for (farm of control.farms; track farm.id) {
                  <div
                    class="enhanced-selection-card"
                    [class.active]="selectedFarmId === farm.id"
                    (click)="selectFarm(farm)"
                  >
                    <div class="enhanced-card-icon">🚜</div>
                    <div class="enhanced-card-title">{{ farm.name }}</div>
                    <div class="enhanced-card-subtitle">{{ farm.region }}</div>
                  </div>
                }
              </div>
            </section>

            <section class="selection-section mt-6" *ngIf="selectedFarmId">
              <h3>{{ 'public_plans.select_farm_size.title' | translate }}</h3>
              <div class="enhanced-grid">
                @for (size of control.farmSizes; track size.id) {
                  <div
                    class="enhanced-selection-card"
                    [class.active]="selectedFarmSizeId === size.id"
                    (click)="selectFarmSize(size)"
                  >
                    <div class="enhanced-card-icon">📐</div>
                    <div class="enhanced-card-title">{{ size.name }}</div>
                    <div class="enhanced-card-highlight">{{ size.area_sqm }}㎡</div>
                    <div class="enhanced-card-detail">{{ size.description }}</div>
                  </div>
                }
              </div>
            </section>
          }
        </div>
      </div>

      <div class="fixed-bottom-bar" *ngIf="canProceed()">
        <div class="fixed-bottom-bar-content">
          <div class="fixed-bottom-bar-left">
            <span class="selection-summary" *ngIf="selectedFarm && selectedFarmSize">
              {{ selectedFarm.name }} / {{ selectedFarmSize.name }}
            </span>
          </div>
          <button type="button" class="btn-gradient btn" (click)="goToCropSelection()">
            {{ 'public_plans.new.title' | translate }} →
          </button>
        </div>
      </div>
    </div>
  `,
  styleUrl: './public-plan.component.css'
})
export class PublicPlanCreateComponent implements PublicPlanCreateView, OnInit {
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadPublicPlanFarmsUseCase);
  private readonly presenter = inject(PublicPlanCreatePresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);

  readonly regions = [
    { value: 'jp', label: 'Japan', flag: '🇯🇵' },
    { value: 'us', label: 'United States', flag: '🇺🇸' },
    { value: 'in', label: 'India', flag: '🇮🇳' }
  ];

  selectedRegion = 'jp';
  selectedFarmId: number | null = null;
  selectedFarmSizeId: string | null = null;
  selectedFarm: Farm | null = null;
  selectedFarmSize: FarmSizeOption | null = null;

  private _control: PublicPlanCreateViewState = initialControl;
  get control(): PublicPlanCreateViewState {
    return this._control;
  }
  set control(value: PublicPlanCreateViewState) {
    this._control = value;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const state = this.publicPlanStore.state;
    if (state.farm) {
      this.selectedFarmId = state.farm.id;
      this.selectedFarm = state.farm;
      this.selectedRegion = state.farm.region ?? 'jp';
    } else {
      this.selectedRegion = this.regionFromPath();
    }
    if (state.farmSize) {
      this.selectedFarmSizeId = state.farmSize.id;
      this.selectedFarmSize = state.farmSize;
    }
    this.loadFarms(this.selectedRegion);
  }

  selectRegion(region: string): void {
    this.selectedRegion = region;
    this.selectedFarmId = null;
    this.selectedFarm = null;
    this.selectedFarmSizeId = null;
    this.selectedFarmSize = null;
    this.control = { ...this.control, loading: true, error: null };
    this.loadFarms(region);
  }

  selectFarm(farm: Farm): void {
    this.selectedFarmId = farm.id;
    this.selectedFarm = farm;
    this.publicPlanStore.setFarm(farm);
  }

  selectFarmSize(size: FarmSizeOption): void {
    this.selectedFarmSizeId = size.id;
    this.selectedFarmSize = size;
    this.publicPlanStore.setFarmSize(size);
  }

  goToCropSelection(): void {
    if (!this.canProceed()) return;
    this.router.navigate(['/public-plans/select-crop']);
  }

  canProceed(): boolean {
    return Boolean(this.selectedFarmId && this.selectedFarmSizeId);
  }

  private loadFarms(region: string): void {
    this.useCase.execute({ region });
  }

  private regionFromPath(): string {
    const segment = window.location.pathname.split('/').filter(Boolean)[0];
    switch (segment) {
      case 'ja':
        return 'jp';
      case 'us':
        return 'us';
      case 'in':
        return 'in';
      default:
        return 'jp';
    }
  }
}
