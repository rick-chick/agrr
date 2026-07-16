import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { TranslateModule } from '@ngx-translate/core';
import { LoadPrivatePlanFarmsUseCase } from '../../usecase/private-plan-create/load-private-plan-farms.usecase';
import { CreatePrivatePlanUseCase } from '../../usecase/private-plan-create/create-private-plan.usecase';
import { PlanNewPresenter, PLAN_NEW_PROVIDERS } from '../../usecase/plans/plan-new.providers';
import { CreatePrivatePlanPresenter } from '../../adapters/private-plan-create/create-private-plan.presenter';
import { PlanNewView, PlanNewViewState } from './plan-new.view';
import { MasterContextHeaderComponent } from '../masters/master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../masters/master-context-header/master-context-crumb';

import { FlashMessageService } from '../../services/flash-message.service';
import { applyPendingFlashAndNavigationViewEffects } from '../../core/view-effects/pending-success-flash-view.effects';

const initialControl: PlanNewViewState = {
  loading: true,
  submitting: false,
  error: null,
  farms: [],
  selectedFarmId: null,
  noFieldsWarning: false,
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
    <main class="page-main">
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
    </main>
  `,
  styleUrls: ['./plan-new.component.css']
})
export class PlanNewComponent implements PlanNewView, OnInit {
  private readonly loadUseCase = inject(LoadPrivatePlanFarmsUseCase);
  private readonly createUseCase = inject(CreatePrivatePlanUseCase);
  private readonly farmsPresenter = inject(PlanNewPresenter);
  private readonly createPresenter = inject(CreatePrivatePlanPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly router = inject(Router);
  private readonly cdr = inject(ChangeDetectorRef);

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
      selectedFarmId: farmId
    };
  }

  onSubmit(event: Event): void {
    event.preventDefault();
    const farmId = this.control.selectedFarmId;
    if (!this.canSubmit || this.control.submitting || farmId == null) {
      return;
    }

    this.control = { ...this.control, submitting: true };
    const trimmedName = this.planName.trim();
    this.createUseCase.execute({
      farmId,
      planName: trimmedName.length > 0 ? trimmedName : undefined
    });
  }
}
