import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PublicPlanSelectCropView, PublicPlanSelectCropViewState } from './public-plan-select-crop.view';
import { LoadPublicPlanCropsUseCase } from '../../usecase/public-plans/load-public-plan-crops.usecase';
import { CreatePublicPlanUseCase } from '../../usecase/public-plans/create-public-plan.usecase';
import { PublicPlanSelectCropPresenter } from '../../adapters/public-plans/public-plan-select-crop.presenter';
import { LOAD_PUBLIC_PLAN_CROPS_OUTPUT_PORT } from '../../usecase/public-plans/load-public-plan-crops.output-port';
import { CREATE_PUBLIC_PLAN_OUTPUT_PORT } from '../../usecase/public-plans/create-public-plan.output-port';
import { PUBLIC_PLAN_GATEWAY } from '../../usecase/public-plans/public-plan-gateway';
import { PublicPlanApiGateway } from '../../adapters/public-plans/public-plan-api.gateway';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { Crop } from '../../domain/crops/crop';

const initialControl: PublicPlanSelectCropViewState = {
  loading: true,
  error: null,
  crops: [],
  saving: false
};

@Component({
  selector: 'app-public-plan-select-crop',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [
    PublicPlanSelectCropPresenter,
    LoadPublicPlanCropsUseCase,
    CreatePublicPlanUseCase,
    { provide: LOAD_PUBLIC_PLAN_CROPS_OUTPUT_PORT, useExisting: PublicPlanSelectCropPresenter },
    { provide: CREATE_PUBLIC_PLAN_OUTPUT_PORT, useExisting: PublicPlanSelectCropPresenter },
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
            <div class="compact-step completed">
              <div class="step-number">1</div>
              <a routerLink="/public-plans/new" class="step-label step-label-link">{{ 'public_plans.steps.region' | translate }}</a>
            </div>
            <div class="compact-step-divider completed"></div>
            <div class="compact-step completed">
              <div class="step-number">2</div>
              <a routerLink="/public-plans/select-farm-size" class="step-label step-label-link">{{ 'public_plans.steps.size' | translate }}</a>
            </div>
            <div class="compact-step-divider completed"></div>
            <div class="compact-step active">
              <div class="step-number">3</div>
              <span class="step-label">{{ 'public_plans.steps.crop' | translate }}</span>
            </div>
          </div>
        </div>

        @if (farm && farmSize) {
        <div class="enhanced-summary-card">
          <div class="enhanced-summary-items">
            <div class="enhanced-summary-row">
              <div class="enhanced-summary-icon">🌍</div>
              <div class="enhanced-summary-content">
                <div class="enhanced-summary-label">{{ 'public_plans.select_crop.summary.region' | translate }}</div>
                <div class="enhanced-summary-value">{{ farm.name }}</div>
              </div>
            </div>
            <div class="enhanced-summary-row">
              <div class="enhanced-summary-icon">🏡</div>
              <div class="enhanced-summary-content">
                <div class="enhanced-summary-label">{{ 'public_plans.select_crop.summary.farm_size' | translate }}</div>
                <div class="enhanced-summary-value">{{ farmSize.name }} ({{ farmSize.area_sqm }}㎡)</div>
              </div>
            </div>
          </div>
        </div>
        }

        <section class="content-card" aria-labelledby="crop-selection-heading">
          <h2 id="crop-selection-heading" class="visually-hidden">{{ 'public_plans.steps.crop' | translate }}</h2>
          @if (control.loading) {
            <div class="loading-state">
              <p>{{ 'common.loading' | translate }}</p>
            </div>
          } @else if (control.error) {
            <div class="create-plan-error-center">
              <p class="create-plan-error-message">{{ 'public_plans.create_failed' | translate:{ errors: control.error } }}</p>
            </div>
          } @else {
            <div class="enhanced-grid">
              @for (crop of control.crops; track crop.id) {
                <div class="crop-item">
                  <input
                    type="checkbox"
                    [id]="'crop_' + crop.id"
                    class="crop-check"
                    [checked]="selectedCropIds.has(crop.id)"
                    (change)="toggleCrop(crop)"
                  />
                  <label [for]="'crop_' + crop.id" class="crop-card">
                    <div class="crop-emoji">🥬</div>
                    <div class="crop-name">{{ crop.name }}</div>
                    @if (crop.variety) { <div class="crop-variety">{{ crop.variety }}</div> }
                    <div class="check-mark">✓</div>
                  </label>
                </div>
              }
            </div>
            <div class="bottom-spacer"></div>
          }
        </section>
      </div>

      @if (!control.error) {
        <div class="fixed-bottom-bar fixed-bottom-bar--create-plan">
          <div class="fixed-bottom-bar-container">
            <div class="fixed-bottom-bar-content fixed-bottom-bar-content--submit-only">
              <button
                type="button"
                class="submit-button btn"
                (click)="createPlan()"
                [disabled]="control.saving || selectedCropIds.size === 0"
              >
                {{ 'public_plans.select_crop.bottom_bar.submit_button' | translate }}
              </button>
            </div>
            @if (selectedCropIds.size === 0) {
              <div class="hint-message">
                {{ 'public_plans.select_crop.bottom_bar.hint' | translate }}
              </div>
            }
          </div>
        </div>
      }
    </main>
  `,
  styleUrl: './public-plan.component.css'
})
export class PublicPlanSelectCropComponent implements PublicPlanSelectCropView, OnInit {
  private readonly router = inject(Router);
  private readonly loadCropsUseCase = inject(LoadPublicPlanCropsUseCase);
  private readonly createPlanUseCase = inject(CreatePublicPlanUseCase);
  private readonly presenter = inject(PublicPlanSelectCropPresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly cdr = inject(ChangeDetectorRef);

  selectedCropIds = new Set<number>();
  selectedCrops: Crop[] = [];

  get farm() {
    return this.publicPlanStore.state.farm;
  }
  get farmSize() {
    return this.publicPlanStore.state.farmSize;
  }

  private _control: PublicPlanSelectCropViewState = initialControl;
  get control(): PublicPlanSelectCropViewState {
    return this._control;
  }
  set control(value: PublicPlanSelectCropViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    if (!this.farm || !this.farmSize) {
      this.router.navigate(['/public-plans/new']);
      return;
    }
    this.presenter.setView(this);
    this.selectedCrops = [...this.publicPlanStore.state.selectedCrops];
    this.selectedCropIds = new Set(this.selectedCrops.map((c) => c.id));
    this.loadCropsUseCase.execute({ farmId: this.farm.id });
  }

  toggleCrop(crop: Crop): void {
    if (this.selectedCropIds.has(crop.id)) {
      this.selectedCropIds.delete(crop.id);
      this.selectedCrops = this.selectedCrops.filter((c) => c.id !== crop.id);
    } else {
      this.selectedCropIds.add(crop.id);
      this.selectedCrops.push(crop);
    }
    this.publicPlanStore.setSelectedCrops(this.selectedCrops);
  }

  createPlan(): void {
    if (
      this.control.saving ||
      this.selectedCropIds.size === 0 ||
      !this.farm ||
      !this.farmSize
    ) {
      return;
    }
    this.control = { ...this.control, saving: true, error: null };
    this.createPlanUseCase.execute({
      farmId: this.farm.id,
      farmSizeId: this.farmSize.id,
      cropIds: Array.from(this.selectedCropIds),
      onSuccess: (response) => {
        this.publicPlanStore.setPlanId(response.plan_id);
        this.router.navigate(['/public-plans/optimizing'], {
          queryParams: { planId: response.plan_id }
        });
      }
    });
  }
}
