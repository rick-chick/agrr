import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FarmEditView, FarmEditViewState, FarmEditFormData } from './farm-edit.view';
import { LoadFarmForEditUseCase } from '../../../usecase/farms/load-farm-for-edit.usecase';
import { UpdateFarmUseCase } from '../../../usecase/farms/update-farm.usecase';
import { FarmEditPresenter } from '../../../adapters/farms/farm-edit.presenter';
import { LOAD_FARM_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/farms/load-farm-for-edit.output-port';
import { UPDATE_FARM_OUTPUT_PORT } from '../../../usecase/farms/update-farm.output-port';
import { FARM_GATEWAY } from '../../../usecase/farms/farm-gateway';
import { FarmApiGateway } from '../../../adapters/farms/farm-api.gateway';
import { FarmMapComponent } from './farm-map.component';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { AuthService } from '../../../services/auth.service';

const initialFormData: FarmEditFormData = {
  name: '',
  region: '',
  latitude: 0,
  longitude: 0
};

const initialControl: FarmEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-farm-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, FarmMapComponent, TranslateModule, RegionSelectComponent],
  providers: [
    FarmEditPresenter,
    LoadFarmForEditUseCase,
    UpdateFarmUseCase,
    { provide: LOAD_FARM_FOR_EDIT_OUTPUT_PORT, useExisting: FarmEditPresenter },
    { provide: UPDATE_FARM_OUTPUT_PORT, useExisting: FarmEditPresenter },
    { provide: FARM_GATEWAY, useClass: FarmApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">Edit Farm</h2>
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
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
                [name]="control.formData.name || 'Farm'"
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
              <button type="submit" class="btn-primary" [disabled]="farmForm.invalid || control.saving">Save</button>
              <a routerLink="/farms" class="btn-secondary">Back to farms</a>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrls: ['./farm-edit.component.css']
})
export class FarmEditComponent implements FarmEditView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadFarmForEditUseCase);
  private readonly updateUseCase = inject(UpdateFarmUseCase);
  private readonly presenter = inject(FarmEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);
  readonly auth = inject(AuthService);

  private _control: FarmEditViewState = initialControl;
  get control(): FarmEditViewState {
    return this._control;
  }
  set control(value: FarmEditViewState) {
    this._control = this.applyUserRegionToControl(value);
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
