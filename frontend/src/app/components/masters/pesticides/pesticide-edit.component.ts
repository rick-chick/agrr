import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { PesticideEditView, PesticideEditViewState, PesticideEditFormData } from './pesticide-edit.view';
import { LoadPesticideForEditUseCase } from '../../../usecase/pesticides/load-pesticide-for-edit.usecase';
import { UpdatePesticideUseCase } from '../../../usecase/pesticides/update-pesticide.usecase';
import { PesticideEditPresenter } from '../../../adapters/pesticides/pesticide-edit.presenter';
import { LOAD_PESTICIDE_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/pesticides/load-pesticide-for-edit.output-port';
import { UPDATE_PESTICIDE_OUTPUT_PORT } from '../../../usecase/pesticides/update-pesticide.output-port';
import { PESTICIDE_GATEWAY } from '../../../usecase/pesticides/pesticide-gateway';
import { PesticideApiGateway } from '../../../adapters/pesticides/pesticide-api.gateway';
import { Crop } from '../../../domain/crops/crop';
import { Pest } from '../../../domain/pests/pest';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { CropApiGateway } from '../../../adapters/crops/crop-api.gateway';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';
import { PestApiGateway } from '../../../adapters/pests/pest-api.gateway';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';

const initialFormData: PesticideEditFormData = {
  name: '',
  active_ingredient: null,
  description: null,
  crop_id: 0,
  pest_id: 0,
  region: null
};

const initialControl: PesticideEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-pesticide-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, RegionSelectComponent, TranslateModule],
  providers: [
    PesticideEditPresenter,
    LoadPesticideForEditUseCase,
    UpdatePesticideUseCase,
    { provide: LOAD_PESTICIDE_FOR_EDIT_OUTPUT_PORT, useExisting: PesticideEditPresenter },
    { provide: UPDATE_PESTICIDE_OUTPUT_PORT, useExisting: PesticideEditPresenter },
    { provide: PESTICIDE_GATEWAY, useClass: PesticideApiGateway },
    { provide: CROP_GATEWAY, useClass: CropApiGateway },
    { provide: PEST_GATEWAY, useClass: PestApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'pesticides.edit.title' | translate }}</h2>
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <form (ngSubmit)="updatePesticide()" #pesticideForm="ngForm" class="form-card__form">
            <label for="name" class="form-card__field">
              <span class="form-card__field-label">{{ 'pesticides.form.name_label' | translate }}</span>
              <input id="name" name="name" [(ngModel)]="control.formData.name" required />
            </label>
            <label for="active_ingredient" class="form-card__field">
              <span class="form-card__field-label">{{ 'pesticides.form.active_ingredient_label' | translate }}</span>
              <input id="active_ingredient" name="active_ingredient" [(ngModel)]="control.formData.active_ingredient" />
            </label>
            <label for="description" class="form-card__field">
              <span class="form-card__field-label">{{ 'pesticides.form.description_label' | translate }}</span>
              <textarea id="description" name="description" [(ngModel)]="control.formData.description"></textarea>
            </label>
            <label for="crop_id" class="form-card__field">
              <span class="form-card__field-label">{{ 'pesticides.form.crop_label' | translate }}</span>
              <select id="crop_id" name="crop_id" [(ngModel)]="control.formData.crop_id" required>
                <option [value]="0">{{ 'pesticides.form.select_crop' | translate }}</option>
                <option *ngFor="let crop of crops" [value]="crop.id">{{ crop.name }}</option>
              </select>
            </label>
            <label for="pest_id" class="form-card__field">
              <span class="form-card__field-label">{{ 'pesticides.form.pest_label' | translate }}</span>
              <select id="pest_id" name="pest_id" [(ngModel)]="control.formData.pest_id" required>
                <option [value]="0">{{ 'pesticides.form.select_pest' | translate }}</option>
                <option *ngFor="let pest of pests" [value]="pest.id">{{ pest.name }}</option>
              </select>
            </label>
            @if (auth.user()?.admin) {
              <app-region-select [region]="control.formData.region" (regionChange)="control.formData.region = $event"></app-region-select>
            }
            <div class="form-card__actions">
              <button type="submit" class="btn-primary" [disabled]="pesticideForm.invalid || control.saving || control.formData.crop_id === 0 || control.formData.pest_id === 0">
                {{ control.saving ? ('common.updating' | translate) : ('pesticides.form.submit_update' | translate) }}
              </button>
              <a [routerLink]="['/pesticides']" class="btn-secondary">{{ 'common.back' | translate }}</a>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrls: ['./pesticide-edit.component.css']
})
export class PesticideEditComponent implements PesticideEditView, OnInit {
  readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadPesticideForEditUseCase);
  private readonly updateUseCase = inject(UpdatePesticideUseCase);
  private readonly presenter = inject(PesticideEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly cropGateway = inject(CROP_GATEWAY);
  private readonly pestGateway = inject(PEST_GATEWAY);

  crops: Crop[] = [];
  pests: Pest[] = [];

  private _control: PesticideEditViewState = initialControl;
  get control(): PesticideEditViewState {
    return this._control;
  }
  set control(value: PesticideEditViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  private get isAdmin(): boolean {
    return this.auth.user()?.admin ?? false;
  }

  private get currentUserRegion(): string | null {
    const user = this.auth.user() as { region?: string | null } | null;
    return user?.region ?? null;
  }

  private applyUserRegionToForm(): void {
    if (this.isAdmin) return;
    this.control = {
      ...this.control,
      formData: {
        ...this.control.formData,
        region: this.currentUserRegion
      }
    };
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.loadCropsAndPests();
    this.applyUserRegionToForm();
    const pesticideId = Number(this.route.snapshot.paramMap.get('id'));
    if (!pesticideId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid pesticide id.' };
      return;
    }
    this.load(pesticideId);
  }

  private loadCropsAndPests(): void {
    this.cropGateway.list().subscribe(crops => this.crops = crops);
    this.pestGateway.list().subscribe(pests => this.pests = pests);
  }

  load(pesticideId: number): void {
    this.control = { ...this.control, loading: true };
    this.loadUseCase.execute({ pesticideId });
  }

  updatePesticide(): void {
    const pesticideId = Number(this.route.snapshot.paramMap.get('id'));
    if (!pesticideId || !this.control.formData.name.trim() || this.control.formData.crop_id === 0 || this.control.formData.pest_id === 0) return;
    const region = this.isAdmin ? this.control.formData.region : this.currentUserRegion;
    this.control = {
      ...this.control,
      saving: true,
      formData: {
        ...this.control.formData,
        region
      }
    };
    this.updateUseCase.execute({
      pesticideId,
      ...this.control.formData,
      region,
      onSuccess: (pesticide) => this.router.navigate(['/pesticides', pesticide.id])
    });
  }
}