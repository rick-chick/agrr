import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PUBLIC_PLAN_GATEWAY } from '../../usecase/public-plans/public-plan-gateway';
import { PublicPlanApiGateway } from '../../adapters/public-plans/public-plan-api.gateway';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { FarmSizeOption } from '../../domain/public-plans/farm-size-option';

@Component({
  selector: 'app-public-plan-select-farm-size',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [{ provide: PUBLIC_PLAN_GATEWAY, useClass: PublicPlanApiGateway }],
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
            <div class="compact-step active">
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

        @if (farm) {
          <div class="enhanced-summary-card enhanced-summary-card--single-row">
            <div class="enhanced-summary-items">
              <div class="enhanced-summary-row">
                <div class="enhanced-summary-icon">🌍</div>
                <div class="enhanced-summary-content">
                  <div class="enhanced-summary-label">{{ 'public_plans.select_farm_size.summary.region' | translate }}</div>
                  <div class="enhanced-summary-value">{{ farm.name }}</div>
                </div>
              </div>
            </div>
          </div>

          <section class="content-card" aria-labelledby="farm-size-heading">
            <h2 id="farm-size-heading" class="visually-hidden">{{ 'public_plans.steps.size' | translate }}</h2>
            @if (loading) {
              <div class="loading-state">
                <p>{{ 'common.loading' | translate }}</p>
              </div>
            } @else if (error) {
              <p class="error-message">{{ error }}</p>
            } @else {
              <div class="enhanced-grid">
                @for (size of farmSizes; track size.id) {
                  <div
                    class="enhanced-selection-card"
                    [class.active]="selectedSizeId === size.id"
                    (click)="selectSize(size)"
                    (keydown.enter)="selectSize(size)"
                    (keydown.space)="selectSize(size); $event.preventDefault()"
                    tabindex="0"
                    role="button"
                  >
                    <div class="enhanced-card-icon">🏡</div>
                    <div class="enhanced-card-title">{{ size.name }}</div>
                    <div class="enhanced-card-highlight">{{ size.area_sqm }}㎡</div>
                    <div class="enhanced-card-detail">{{ size.description }}</div>
                  </div>
                }
              </div>
            }
          </section>
        }
      </div>
    </main>
  `,
  styleUrls: ['./public-plan.component.css']
})
export class PublicPlanSelectFarmSizeComponent implements OnInit {
  private readonly router = inject(Router);
  private readonly gateway = inject(PUBLIC_PLAN_GATEWAY);
  private readonly store = inject(PublicPlanStore);
  private readonly cdr = inject(ChangeDetectorRef);

  loading = true;
  error: string | null = null;
  farmSizes: FarmSizeOption[] = [];
  selectedSizeId: string | null = null;

  get farm() {
    return this.store.state.farm;
  }

  ngOnInit(): void {
    if (!this.farm) {
      this.router.navigate(['/public-plans/new']);
      return;
    }
    this.gateway.getFarmSizes().subscribe({
      next: (sizes) => {
        this.farmSizes = sizes;
        this.loading = false;
        this.error = null;
        this.cdr.markForCheck();
      },
      error: (err: Error) => {
        this.error = err?.message ?? 'Unknown error';
        this.loading = false;
        this.cdr.markForCheck();
      }
    });
  }

  selectSize(size: FarmSizeOption): void {
    this.selectedSizeId = size.id;
    this.store.setFarmSize(size);
    this.router.navigate(['/public-plans/select-crop']);
  }
}
