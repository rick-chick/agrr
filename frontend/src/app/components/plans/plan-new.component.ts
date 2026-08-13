import { Component, DestroyRef, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { LoadPrivatePlanFarmsUseCase } from '../../usecase/private-plan-create/load-private-plan-farms.usecase';
import { CreatePrivatePlanUseCase } from '../../usecase/private-plan-create/create-private-plan.usecase';
import { PlanNewPresenter, PLAN_NEW_PROVIDERS } from '../../usecase/plans/plan-new.providers';
import { CreatePrivatePlanPresenter } from '../../adapters/private-plan-create/create-private-plan.presenter';
import { PlanNewView, PlanNewViewState } from './plan-new.view';
import { MasterContextHeaderComponent } from '../masters/master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../masters/master-context-header/master-context-crumb';
import { LoadPlanNewCarryoverUseCase } from '../../usecase/plans/load-plan-new-carryover.usecase';
import type { PlanVsActualCategorySummary } from '../../domain/plans/plan-vs-actual-summary';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';

import { FlashMessageService } from '../../services/flash-message.service';
import { applyPendingFlashAndNavigationViewEffects } from '../../core/view-effects/pending-success-flash-view.effects';

const initialControl: PlanNewViewState = {
  loading: true,
  submitting: false,
  error: null,
  farms: [],
  selectedFarmId: null,
  noFieldsWarning: false,
  carryoverEnabled: false,
  sourcePlans: [],
  selectedSourcePlanId: null,
  carryoverPreviewLoading: false,
  carryoverPreviewError: null,
  carryoverPreview: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  pendingNavigation: null
};

@Component({
  selector: 'app-plan-new',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, FormsModule, MasterContextHeaderComponent],
  providers: [...PLAN_NEW_PROVIDERS],
  template: `
    <div class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'plans.new.title' | translate }}</h1>
        <p class="page-description">{{ 'plans.new.subtitle' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <p class="plan-new-error">{{ control.error }}</p>
        } @else if (control.farms.length === 0) {
          <div class="plan-new-empty">
            <p>{{ 'plans.new.no_farms' | translate }}</p>
            <p class="plan-new-empty-hint">{{ 'plans.new.no_farms_hint' | translate }}</p>
            <a routerLink="/farms/new" class="btn btn-primary">{{ 'plans.new.create_farm_link' | translate }}</a>
          </div>
        } @else {
          <form class="form" (ngSubmit)="onSubmit($event)">
            <div class="form-group">
              <label for="farm-select" class="form-label">{{ 'plans.new.farm_label' | translate }}</label>
              @if (farmsWithoutFields.length > 0) {
                @if (onlyFarmsWithoutFields) {
                  <p class="plan-new-warning" role="status">
                    {{ 'plans.new.no_fields_warning' | translate }}
                    @if (noFieldsRegisterLinkFarmId != null) {
                      <a
                        class="plan-new-warning__link"
                        [routerLink]="['/farms', noFieldsRegisterLinkFarmId]"
                      >
                        {{ 'plans.new.register_fields_link' | translate }}
                      </a>
                    }
                  </p>
                } @else {
                  <p class="plan-new-warning" role="status">
                    {{ 'plans.new.some_farms_no_fields_hint' | translate }}
                  </p>
                  @for (farm of farmsWithoutFields; track farm.id) {
                    <p class="plan-new-warning plan-new-warning--farm" role="status">
                      {{ farm.name }}
                      <a class="plan-new-warning__link" [routerLink]="['/farms', farm.id]">
                        {{ 'plans.new.register_fields_link' | translate }}
                      </a>
                    </p>
                  }
                }
              }
              <select
                id="farm-select"
                name="farmId"
                class="form-control"
                required
                [disabled]="control.submitting"
                [ngModel]="control.selectedFarmId"
                (ngModelChange)="onFarmChange($event)"
              >
                <option [ngValue]="null">{{ 'plans.new.farm_hint' | translate }}</option>
                @for (farm of control.farms; track farm.id) {
                  <option [ngValue]="farm.id" [disabled]="!farm.hasValidFields">
                    @if (farm.hasValidFields) {
                      {{ 'plans.new.farm_option_with_fields' | translate: { name: farm.name, count: farm.fieldCount, area: farm.totalArea } }}
                    } @else {
                      {{ 'plans.new.farm_option_no_fields' | translate: { name: farm.name } }}
                    }
                  </option>
                }
              </select>
            </div>
            <div class="form-group">
              <label for="plan-name" class="form-label">{{ 'plans.new.plan_name_label' | translate }}</label>
              <input
                id="plan-name"
                name="planName"
                type="text"
                class="form-control"
                [placeholder]="'plans.new.plan_name_placeholder' | translate"
                [disabled]="control.submitting"
                [(ngModel)]="planName"
              />
              @if (selectedFarmName) {
                <p class="form-hint">{{ 'plans.new.suggested_plan_name_hint' | translate: { name: selectedFarmName } }}</p>
              }
            </div>
            <div class="form-group">
              <label class="plan-new-carryover-toggle">
                <input
                  type="checkbox"
                  name="carryoverEnabled"
                  [disabled]="control.submitting"
                  [ngModel]="control.carryoverEnabled"
                  (ngModelChange)="onCarryoverEnabledChange($event)"
                />
                {{ 'plans.new.carryover_enabled_label' | translate }}
              </label>
              @if (control.carryoverEnabled) {
                <p class="form-hint">{{ 'plans.new.carryover_hint' | translate }}</p>
                @if (control.selectedFarmId != null) {
                  <label for="carryover-source-plan" class="form-label">{{
                    'plans.new.carryover_source_label' | translate
                  }}</label>
                  <p class="form-hint">{{ 'plans.new.carryover_source_hint' | translate }}</p>
                  @if (control.sourcePlans.length === 0) {
                    <p class="plan-new-warning" role="status">{{
                      'plans.new.carryover_no_source_plans' | translate
                    }}</p>
                  } @else {
                    <select
                      id="carryover-source-plan"
                      name="sourcePlanId"
                      class="form-control"
                      [disabled]="control.submitting"
                      [ngModel]="control.selectedSourcePlanId"
                      (ngModelChange)="onSourcePlanChange($event)"
                    >
                      <option [ngValue]="null">{{ 'plans.new.carryover_source_hint' | translate }}</option>
                      @for (plan of control.sourcePlans; track plan.id) {
                        <option [ngValue]="plan.id">{{ plan.name }}</option>
                      }
                    </select>
                  }
                  @if (control.selectedSourcePlanId != null) {
                    @if (control.carryoverPreviewLoading) {
                      <p class="master-loading">{{ 'common.loading' | translate }}</p>
                    } @else if (control.carryoverPreviewError) {
                      <p class="plan-new-error">{{ control.carryoverPreviewError }}</p>
                    } @else if (control.carryoverPreview) {
                      <div class="plan-new-carryover-preview">
                        <h3 class="plan-new-carryover-preview__title">{{
                          'plans.new.carryover_preview_title' | translate
                        }}</h3>
                        @if (control.carryoverPreview.categories.length) {
                          <table class="plan-new-carryover-preview__table">
                            <thead>
                              <tr>
                                <th scope="col">{{
                                  'plans.task_schedules.variance_subview.category_column' | translate
                                }}</th>
                                <th scope="col">{{
                                  'plans.task_schedules.variance_subview.category_average' | translate
                                }}</th>
                              </tr>
                            </thead>
                            <tbody>
                              @for (category of control.carryoverPreview.categories; track category.category) {
                                <tr>
                                  <td>{{ categoryLabel(category) }}</td>
                                  <td>{{ categoryAverageLabel(category) }}</td>
                                </tr>
                              }
                            </tbody>
                          </table>
                      } @else {
                        <p class="form-hint">{{ 'plans.new.carryover_preview_empty' | translate }}</p>
                      }
                      <button
                        type="button"
                        class="btn btn-secondary plan-new-carryover-learn-cta"
                        [disabled]="control.submitting"
                        (click)="onSubmitWithLearnReview($event)"
                      >
                        {{ 'plans.new.carryover_learn_cta' | translate }}
                      </button>
                    </div>
                    }
                  }
                }
              }
            </div>
            <div class="form-actions">
              <button
                type="submit"
                class="btn btn-primary"
                [disabled]="control.submitting || !canSubmit"
              >
                {{ control.submitting ? ('common.loading' | translate) : ('plans.new.create_button' | translate) }}
              </button>
            </div>
          </form>
        }
      </section>
    </div>
  `,
  styleUrls: ['./plan-new.component.css']
})
export class PlanNewComponent implements PlanNewView, OnInit {
  private readonly loadUseCase = inject(LoadPrivatePlanFarmsUseCase);
  private readonly createUseCase = inject(CreatePrivatePlanUseCase);
  private readonly farmsPresenter = inject(PlanNewPresenter);
  private readonly createPresenter = inject(CreatePrivatePlanPresenter);
  private readonly carryoverUseCase = inject(LoadPlanNewCarryoverUseCase);
  private readonly translate = inject(TranslateService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly router = inject(Router);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  planName = '';

  get contextCrumbs(): MasterContextCrumb[] {
    return [
      { labelKey: 'plans.index.title', routerLink: ['/plans'] },
      { labelKey: 'plans.new.breadcrumb' }
    ];
  }

  private _control: PlanNewViewState = initialControl;
  get control(): PlanNewViewState {
    return this._control;
  }
  set control(value: PlanNewViewState) {
    this._control = applyPendingFlashAndNavigationViewEffects(value, {
      flash: this.flashMessage,
      router: this.router
    });
    this.cdr.markForCheck();
  }

  get selectedFarmName(): string | null {
    const farm = this.control.farms.find((f) => f.id === this.control.selectedFarmId);
    return farm?.name ?? null;
  }

  get farmsWithoutFields() {
    return this.control.farms.filter((farm) => !farm.hasValidFields);
  }

  get onlyFarmsWithoutFields(): boolean {
    return this.control.farms.length > 0 && this.control.farms.every((farm) => !farm.hasValidFields);
  }

  get noFieldsRegisterLinkFarmId(): number | null {
    const withoutFields = this.farmsWithoutFields;
    if (withoutFields.length === 1) {
      return withoutFields[0].id;
    }
    return null;
  }

  get canSubmit(): boolean {
    const farm = this.control.farms.find((f) => f.id === this.control.selectedFarmId);
    return Boolean(farm?.hasValidFields);
  }

  ngOnInit(): void {
    this.farmsPresenter.setView(this);
    this.createPresenter.setView(this);
    this.load();
  }

  load(): void {
    this.control = { ...this.control, loading: true, error: null };
    this.loadUseCase.execute();
  }

  onFarmChange(farmId: number | null): void {
    this.control = {
      ...this.control,
      selectedFarmId: farmId,
      selectedSourcePlanId: null,
      carryoverPreview: null,
      carryoverPreviewError: null,
      carryoverPreviewLoading: false,
      sourcePlans: []
    };
    if (this.control.carryoverEnabled && farmId != null) {
      this.loadSourcePlans(farmId);
    }
  }

  onCarryoverEnabledChange(enabled: boolean): void {
    this.control = {
      ...this.control,
      carryoverEnabled: enabled,
      selectedSourcePlanId: null,
      carryoverPreview: null,
      carryoverPreviewError: null,
      carryoverPreviewLoading: false,
      sourcePlans: []
    };
    if (enabled && this.control.selectedFarmId != null) {
      this.loadSourcePlans(this.control.selectedFarmId);
    }
  }

  onSourcePlanChange(planId: number | null): void {
    this.control = {
      ...this.control,
      selectedSourcePlanId: planId,
      carryoverPreview: null,
      carryoverPreviewError: null,
      carryoverPreviewLoading: planId != null
    };
    if (planId != null) {
      this.loadCarryoverPreview(planId);
    }
  }

  categoryLabel(category: PlanVsActualCategorySummary): string {
    return this.translate.instant(
      `plans.task_schedules.variance_subview.category.${category.category}`
    );
  }

  categoryAverageLabel(category: PlanVsActualCategorySummary): string {
    if (category.average_delta_days == null) {
      return this.translate.instant('plans.task_schedules.variance_subview.not_available');
    }
    return this.translate.instant('plans.task_schedules.variance_subview.average_value', {
      delta: formatPlanTaskScheduleAverageDeltaDaysLabel(category.average_delta_days)
    });
  }

  onSubmit(event: Event, navigateToLearnAfterCreate = false): void {
    event.preventDefault();
    const farmId = this.control.selectedFarmId;
    if (!this.canSubmit || this.control.submitting || farmId == null) {
      return;
    }

    this.control = { ...this.control, submitting: true };
    const trimmedName = this.planName.trim();
    const input: {
      farmId: number;
      planName?: string;
      carryoverFromPlanId?: number;
      navigateToLearnAfterCreate?: boolean;
    } = {
      farmId,
      planName: trimmedName.length > 0 ? trimmedName : undefined,
      navigateToLearnAfterCreate
    };
    if (this.control.carryoverEnabled && this.control.selectedSourcePlanId != null) {
      input.carryoverFromPlanId = this.control.selectedSourcePlanId;
    }
    this.createUseCase.execute(input);
  }

  onSubmitWithLearnReview(event: Event): void {
    this.onSubmit(event, true);
  }

  private loadSourcePlans(farmId: number): void {
    this.carryoverUseCase
      .loadSourcePlans(farmId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (sourcePlans) => {
          this.control = {
            ...this.control,
            sourcePlans
          };
        },
        error: () => {
          this.control = {
            ...this.control,
            sourcePlans: []
          };
        }
      });
  }

  private loadCarryoverPreview(planId: number): void {
    this.carryoverUseCase
      .loadCarryoverPreview(planId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (summary) => {
          this.control = {
            ...this.control,
            carryoverPreviewLoading: false,
            carryoverPreviewError: null,
            carryoverPreview: summary
          };
        },
        error: (err: Error) => {
          this.control = {
            ...this.control,
            carryoverPreviewLoading: false,
            carryoverPreviewError: err.message,
            carryoverPreview: null
          };
        }
      });
  }
}
