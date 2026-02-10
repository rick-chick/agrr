import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { FarmCreateView, FarmCreateViewState, FarmCreateFormData } from './farm-create.view';
import { CreateFarmUseCase } from '../../../usecase/farms/create-farm.usecase';
import { FarmCreatePresenter } from '../../../adapters/farms/farm-create.presenter';
import { CREATE_FARM_OUTPUT_PORT } from '../../../usecase/farms/create-farm.output-port';
import { FARM_GATEWAY } from '../../../usecase/farms/farm-gateway';
import { FarmApiGateway } from '../../../adapters/farms/farm-api.gateway';
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

const initialControl: FarmCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-farm-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, FarmMapComponent, RegionSelectComponent, TranslateModule],
  providers: [
    FarmCreatePresenter,
    CreateFarmUseCase,
    { provide: CREATE_FARM_OUTPUT_PORT, useExisting: FarmCreatePresenter },
    { provide: FARM_GATEWAY, useClass: FarmApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'farms.new.title' | translate }}</h2>
        <form (ngSubmit)="createFarm()" #farmForm="ngForm" class="form-card__form">
          <label class="form-card__field" for="name">
            <span class="form-card__field-label">{{ 'farms.new.form.name_label' | translate }}</span>
            <input id="name" name="name" [(ngModel)]="control.formData.name" required />
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
          </div>
          <div class="form-card__actions">
            <button type="submit" class="btn-primary" [disabled]="farmForm.invalid || control.saving">
              {{ 'farms.new.form.submit' | translate }}
            </button>
            <a routerLink="/farms" class="btn-secondary">{{ 'farms.show.back_to_list' | translate }}</a>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrls: ['./farm-create.component.css']
})
export class FarmCreateComponent implements FarmCreateView, OnInit {
  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateFarmUseCase);
  private readonly presenter = inject(FarmCreatePresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

  private _control: FarmCreateViewState = initialControl;
  get control(): FarmCreateViewState {
    return this._control;
  }
  set control(value: FarmCreateViewState) {
    this._control = value;
    this.cdr.markForCheck();
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
