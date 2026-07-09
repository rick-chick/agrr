import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { FarmEditView, FarmEditViewState, FarmEditFormData } from './farm-edit.view';
import { LoadFarmForEditUseCase } from '../../../usecase/farms/load-farm-for-edit.usecase';
import { UpdateFarmUseCase } from '../../../usecase/farms/update-farm.usecase';
import {
  FarmEditPresenter,
  FARM_EDIT_PROVIDERS
} from '../../../usecase/farms/farm-edit.providers';
import { FarmMapComponent } from './farm-map.component';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { AuthService } from '../../../services/auth.service';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';

const initialFormData: FarmEditFormData = {
  name: '',
  region: '',
  latitude: 0,
  longitude: 0
};

import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';

const initialControl: FarmEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-farm-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, FarmMapComponent, TranslateModule, RegionSelectComponent, MasterContextHeaderComponent],
  providers: [...FARM_EDIT_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'farms.edit.title' | translate }}</h2>
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <form (ngSubmit)="updateFarm()" #farmForm="ngForm" class="form-card__form">
            <label class="form-card__field" for="name">
              <span class="form-card__field-label">{{ 'farms.new.form.name_label' | translate }}</span>
              <input id="name" name="name" [(ngModel)]="control.formData.name" required />
            </label>
            @if (isAdmin) {
              <app-region-select
                [region]="control.formData.region"
                [required]="true"
                (regionChange)="control.formData.region = $event || ''"
              ></app-region-select>
            }
            <section class="section-card" aria-labelledby="location-heading">
              <h3 id="location-heading" class="section-title">{{ 'farms.new.form.location_label' | translate }}</h3>
              <app-farm-map
                [editable]="true"
                [latitude]="control.formData.latitude"
                [longitude]="control.formData.longitude"
                [name]="control.formData.name || ('farms.map.default_name' | translate)"
                (coordinatesChange)="onCoordinatesChange($event)"
              />
              <div class="coordinates-input">
                <label class="form-card__field" for="latitude">
                  <span class="form-card__field-label">{{ 'farms.new.form.latitude_label' | translate }}</span>
                  <input
                    id="latitude"
                    name="latitude"
                    type="number"
                    step="0.000001"
                    min="-90"
                    max="90"
                    [placeholder]="'farms.new.form.latitude_placeholder' | translate"
                    [(ngModel)]="control.formData.latitude"
                    required
                  />
                </label>
                <label class="form-card__field" for="longitude">
                  <span class="form-card__field-label">{{ 'farms.new.form.longitude_label' | translate }}</span>
                  <input
                    id="longitude"
                    name="longitude"
                    type="number"
                    step="0.000001"
                    min="-180"
                    max="180"
                    [placeholder]="'farms.new.form.longitude_placeholder' | translate"
                    [(ngModel)]="control.formData.longitude"
                    required
                  />
                </label>
              </div>
            </section>
            <div class="form-card__actions">
              <button type="submit" class="btn-primary" [disabled]="farmForm.invalid || control.saving">
                {{ 'farms.edit.form.submit' | translate }}
              </button>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrls: ['./farm-edit.component.css']
})
export class FarmEditComponent implements FarmEditView, OnInit {
  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'farms.index.title', routerLink: ['/farms'] }
    ];
    if (!this.control.loading && this.control.formData.name) {
      crumbs.push({ label: this.control.formData.name, routerLink: ['/farms', this.farmId] });
    }
    crumbs.push({ labelKey: 'common.edit' });
    return crumbs;
  }

  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadFarmForEditUseCase);
  private readonly updateUseCase = inject(UpdateFarmUseCase);
  private readonly presenter = inject(FarmEditPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);
  readonly auth = inject(AuthService);

  private _control: FarmEditViewState = initialControl;
  get control(): FarmEditViewState {
    return this._control;
  }
  set control(value: FarmEditViewState) {
    const next = applyPendingErrorFlashViewEffects(this.applyUserRegionToControl(value), {
      flash: this.flashMessage
    });
    this._control = next;
    this.cdr.markForCheck();
  }

  private get farmId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.farmId) {
      // Presenter will handle invalid farm id error
      return;
    }
    this.loadUseCase.execute({ farmId: this.farmId });
  }

  onCoordinatesChange(event: { latitude: number; longitude: number }): void {
    this.control = {
      ...this.control,
      formData: {
        ...this.control.formData,
        latitude: event.latitude,
        longitude: event.longitude
      }
    };
  }

  updateFarm(): void {
    const { latitude, longitude } = this.control.formData;
    if (
      Number.isNaN(latitude) ||
      Number.isNaN(longitude) ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      this.control = {
        ...this.control,
        error: this.translate.instant('farms.new.form.coordinates_validation_error')
      };
      return;
    }
    this.control = { ...this.control, error: null };
    const region = this.isAdmin ? this.control.formData.region : this.userRegion ?? this.control.formData.region;
    this.updateUseCase.execute({
      farmId: this.farmId,
      name: this.control.formData.name,
      region,
      latitude: this.control.formData.latitude,
      longitude: this.control.formData.longitude,
      onSuccess: () => this.router.navigate(['/farms', this.farmId])
    });
  }

  get isAdmin(): boolean {
    return this.auth.user()?.admin ?? false;
  }

  private get userRegion(): string | null {
    const user = this.auth.user() as { region?: string | null } | null;
    return user?.region ?? null;
  }

  private applyUserRegionToControl(state: FarmEditViewState): FarmEditViewState {
    if (this.isAdmin) return state;
    const region = this.userRegion;
    if (!region) return state;
    if (state.formData.region === region) return state;
    return {
      ...state,
      formData: {
        ...state.formData,
        region
      }
    };
  }
}
