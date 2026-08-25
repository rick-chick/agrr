import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, NgForm } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';
import { FarmCreateView, FarmCreateViewState, FarmCreateFormData } from './farm-create.view';
import { CreateFarmUseCase } from '../../../usecase/farms/create-farm.usecase';
import {
  FarmCreatePresenter,
  FARM_CREATE_PROVIDERS
} from '../../../usecase/farms/farm-create.providers';
import { FARM_GATEWAY, FarmGateway } from '../../../usecase/farms/farm-gateway';
import {
  countUserOwnedFarms,
  isFarmCreateLimitReached
} from '../../../domain/farms/farm-create-limit';
import { FarmMapComponent } from './farm-map.component';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { FormFieldComponent } from '../../shared/form-field/form-field.component';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { CurrentUser } from '../../../services/api.service';
import { detectBrowserRegion } from '../../../core/browser-region';
import {
  formCardAriaDescribedbyForRequired,
  formCardAriaInvalidForRequired,
  formCardFieldErrorId,
  formCardRequiredValueInvalid,
  formCardShowsRequiredError
} from '../../../core/form-card-field-a11y';

const DEFAULT_LAT = 35.6812;
const DEFAULT_LNG = 139.7671;

const initialFormData: FarmCreateFormData = {
  name: '',
  region: '',
  latitude: DEFAULT_LAT,
  longitude: DEFAULT_LNG
};

import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';

const initialControl: FarmCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData,
  limitCheckLoading: true,
  limitBlocked: false,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-farm-create',
  standalone: true,
  imports: [CommonModule, FormsModule, FarmMapComponent, RegionSelectComponent, FormFieldComponent, TranslateModule, MasterContextHeaderComponent, RouterLink],
  providers: [...FARM_CREATE_PROVIDERS],
  template: `
    <div class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'farms.new.title' | translate }}</h2>
        @if (control.limitCheckLoading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.limitBlocked) {
          <div class="plan-new-empty" role="status">
            <p>{{ 'farms.new.limit_reached' | translate }}</p>
            <p class="plan-new-empty-hint">{{ 'farms.new.limit_reached_hint' | translate }}</p>
            <a routerLink="/farms" class="btn btn-primary">{{ 'farms.new.manage_farms_link' | translate }}</a>
          </div>
        } @else {
        <form (ngSubmit)="createFarm(farmForm)" #farmForm="ngForm" class="form-card__form">
          <app-form-field
            inputId="name"
            name="name"
            labelKey="farms.new.form.name_label"
            [required]="true"
            [formSubmitted]="formSubmitted"
            [value]="control.formData.name"
            (valueChange)="onNameChange($event)"
          />
          @if (auth.user()?.admin) {
            <app-region-select
              id="region"
              [region]="control.formData.region"
              [required]="true"
              [formSubmitted]="formSubmitted"
              [invalid]="requiredValueInvalid(control.formData.region)"
              (regionChange)="control.formData.region = $event || ''"
            ></app-region-select>
          }
          <div class="form-group">
            <label class="form-label">{{ 'farms.new.form.location_label' | translate }}</label>
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
                  [class.form-card__input--invalid]="showsRequiredError(formSubmitted, control.formData.latitude)"
                  [attr.aria-invalid]="ariaInvalidForRequired(formSubmitted, control.formData.latitude)"
                  [attr.aria-describedby]="ariaDescribedbyForRequired('latitude', formSubmitted, control.formData.latitude)"
                />
                @if (showsRequiredError(formSubmitted, control.formData.latitude)) {
                  <span [id]="fieldErrorId('latitude')" class="form-card__field-error" role="alert">
                    {{ 'common.form.required_field' | translate }}
                  </span>
                }
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
                  [class.form-card__input--invalid]="showsRequiredError(formSubmitted, control.formData.longitude)"
                  [attr.aria-invalid]="ariaInvalidForRequired(formSubmitted, control.formData.longitude)"
                  [attr.aria-describedby]="ariaDescribedbyForRequired('longitude', formSubmitted, control.formData.longitude)"
                />
                @if (showsRequiredError(formSubmitted, control.formData.longitude)) {
                  <span [id]="fieldErrorId('longitude')" class="form-card__field-error" role="alert">
                    {{ 'common.form.required_field' | translate }}
                  </span>
                }
              </label>
            </div>
          </div>
          <div class="form-card__actions">
            <button type="submit" class="btn btn-primary" [disabled]="control.saving">
              {{ 'farms.new.form.submit' | translate }}
            </button>
          </div>
        </form>
        }
      </section>
    </div>
  `,
  styleUrls: ['./farm-create.component.css']
})
export class FarmCreateComponent implements FarmCreateView, OnInit {
  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateFarmUseCase);
  private readonly presenter = inject(FarmCreatePresenter);
  private readonly farmGateway = inject<FarmGateway>(FARM_GATEWAY);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

  formSubmitted = false;

  readonly fieldErrorId = formCardFieldErrorId;
  readonly requiredValueInvalid = formCardRequiredValueInvalid;
  readonly showsRequiredError = formCardShowsRequiredError;
  readonly ariaInvalidForRequired = formCardAriaInvalidForRequired;
  readonly ariaDescribedbyForRequired = formCardAriaDescribedbyForRequired;

  private _control: FarmCreateViewState = initialControl;
  get control(): FarmCreateViewState {
    return this._control;
  }
  set control(value: FarmCreateViewState) {
    this._control = applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage });
    this.cdr.markForCheck();
  }

  get contextCrumbs(): MasterContextCrumb[] {
    return [
      { labelKey: 'farms.index.title', routerLink: ['/farms'] },
      { labelKey: 'farms.new.title' }
    ];
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.applyUserRegion(this.auth.user());
    this.auth.loadCurrentUser().subscribe((user) => this.applyUserRegion(user));
    this.farmGateway.list().subscribe({
      next: (farms) => {
        const limitBlocked = isFarmCreateLimitReached(countUserOwnedFarms(farms));
        this.control = {
          ...this.control,
          limitCheckLoading: false,
          limitBlocked
        };
      },
      error: () => {
        this.control = {
          ...this.control,
          limitCheckLoading: false,
          limitBlocked: false
        };
      }
    });
  }

  onNameChange(value: string | number | null): void {
    this.control.formData.name = value == null ? '' : String(value);
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

  createFarm(form?: NgForm): void {
    this.formSubmitted = true;
    if (form?.invalid) {
      for (const control of Object.values(form.controls)) {
        control.markAsTouched();
      }
      return;
    }
    const region = this.ensureRegionForSubmit(this.auth.user());
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
    this.useCase.execute({
      name: this.control.formData.name,
      region,
      latitude: this.control.formData.latitude,
      longitude: this.control.formData.longitude,
      onSuccess: (farm) => this.router.navigate(['/farms', farm.id])
    });
  }

  private applyUserRegion(user: CurrentUser | null): void {
    if (!user || user.admin) return;
    const region = this.resolveUserRegion(user);
    if (!region || this.control.formData.region === region) return;
    this.control = {
      ...this.control,
      formData: {
        ...this.control.formData,
        region
      }
    };
  }

  private ensureRegionForSubmit(user: CurrentUser | null): string {
    if (user?.admin) {
      return this.control.formData.region;
    }
    const region = this.resolveUserRegion(user);
    if (region && this.control.formData.region !== region) {
      this.control = {
        ...this.control,
        formData: {
          ...this.control.formData,
          region
        }
      };
    }
    return region || this.control.formData.region;
  }

  private resolveUserRegion(user: CurrentUser | null): string {
    return user?.region ?? detectBrowserRegion();
  }
}
