import { Component, OnInit, inject, ChangeDetectorRef, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, NgForm } from '@angular/forms';
import { Router } from '@angular/router';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';
import { FarmCreateView, FarmCreateViewState, FarmCreateFormData } from './farm-create.view';
import { CreateFarmUseCase } from '../../../usecase/farms/create-farm.usecase';
import {
  FarmCreatePresenter,
  FARM_CREATE_PROVIDERS
} from '../../../usecase/farms/farm-create.providers';
import { FarmMapComponent } from './farm-map.component';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { CurrentUser } from '../../../services/api.service';
import { detectBrowserRegion } from '../../../core/browser-region';

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
import {
  FormCardNgControl,
  formCardFieldAriaDescribedby,
  formCardFieldAriaInvalid,
  formCardFieldErrorId,
  formCardFieldShowError
} from '../../../core/form-card-field-a11y';

const initialControl: FarmCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-farm-create',
  standalone: true,
  imports: [CommonModule, FormsModule, FarmMapComponent, RegionSelectComponent, TranslateModule, MasterContextHeaderComponent],
  providers: [...FARM_CREATE_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'farms.new.title' | translate }}</h2>
        <form (ngSubmit)="createFarm()" #farmForm="ngForm" class="form-card__form" novalidate>
          <label class="form-card__field" for="name">
            <span class="form-card__field-label">{{ 'farms.new.form.name_label' | translate }}</span>
            <input
              id="name"
              name="name"
              [(ngModel)]="control.formData.name"
              required
              #nameField="ngModel"
              [attr.aria-invalid]="fieldAriaInvalid(nameField)"
              [attr.aria-describedby]="fieldAriaDescribedby(nameField, 'name')"
              [class.form-card__field-input--invalid]="fieldShowError(nameField)"
            />
            @if (fieldShowError(nameField)) {
              <span [id]="fieldErrorId('name')" class="form-card__field-error" role="alert">
                {{ fieldErrorMessage(nameField) | translate }}
              </span>
            }
          </label>
          @if (auth.user()?.admin) {
            <app-region-select
              id="region"
              [region]="control.formData.region"
              [required]="true"
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
                  #latitudeField="ngModel"
                  [attr.aria-invalid]="fieldAriaInvalid(latitudeField, fieldErrors['latitude'])"
                  [attr.aria-describedby]="fieldAriaDescribedby(latitudeField, 'latitude', fieldErrors['latitude'])"
                  [class.form-card__field-input--invalid]="fieldShowError(latitudeField, fieldErrors['latitude'])"
                />
                @if (fieldShowError(latitudeField, fieldErrors['latitude'])) {
                  <span [id]="fieldErrorId('latitude')" class="form-card__field-error" role="alert">
                    {{ fieldErrorMessage(latitudeField, fieldErrors['latitude']) | translate }}
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
                  #longitudeField="ngModel"
                  [attr.aria-invalid]="fieldAriaInvalid(longitudeField, fieldErrors['longitude'])"
                  [attr.aria-describedby]="fieldAriaDescribedby(longitudeField, 'longitude', fieldErrors['longitude'])"
                  [class.form-card__field-input--invalid]="fieldShowError(longitudeField, fieldErrors['longitude'])"
                />
                @if (fieldShowError(longitudeField, fieldErrors['longitude'])) {
                  <span [id]="fieldErrorId('longitude')" class="form-card__field-error" role="alert">
                    {{ fieldErrorMessage(longitudeField, fieldErrors['longitude']) | translate }}
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
      </section>
    </main>
  `,
  styleUrls: ['./farm-create.component.css']
})
export class FarmCreateComponent implements FarmCreateView, OnInit {
  @ViewChild('farmForm') farmForm?: NgForm;

  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateFarmUseCase);
  private readonly presenter = inject(FarmCreatePresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

  formSubmitted = false;
  fieldErrors: Record<string, string | null> = {};

  readonly fieldErrorId = formCardFieldErrorId;

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

  createFarm(): void {
    this.formSubmitted = true;
    this.fieldErrors = {};
    this.cdr.markForCheck();

    const { latitude, longitude } = this.control.formData;
    if (
      Number.isNaN(latitude) ||
      Number.isNaN(longitude) ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      const coordinatesError = 'farms.new.form.coordinates_validation_error';
      this.fieldErrors = {
        latitude: coordinatesError,
        longitude: coordinatesError
      };
      this.control = {
        ...this.control,
        error: this.translate.instant(coordinatesError)
      };
      return;
    }

    if (this.farmForm?.invalid) {
      return;
    }

    const region = this.ensureRegionForSubmit(this.auth.user());
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

  fieldShowError(
    control: FormCardNgControl,
    customError?: string | null,
    submitted = this.formSubmitted
  ): boolean {
    return formCardFieldShowError(control, {
      submitted,
      customError
    });
  }

  fieldAriaInvalid(
    control: FormCardNgControl,
    customError?: string | null,
    submitted = this.formSubmitted
  ): true | null {
    return formCardFieldAriaInvalid(this.fieldShowError(control, customError, submitted));
  }

  fieldAriaDescribedby(
    control: FormCardNgControl,
    fieldId: string,
    customError?: string | null,
    submitted = this.formSubmitted
  ): string | null {
    return formCardFieldAriaDescribedby(
      this.fieldShowError(control, customError, submitted),
      fieldId
    );
  }

  fieldErrorMessage(control: FormCardNgControl, customError?: string | null): string {
    return customError ?? 'common.form_field.required';
  }
}
