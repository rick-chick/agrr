import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { CropEditView, CropEditViewState, CropEditFormData } from './crop-edit.view';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { UpdateCropUseCase } from '../../../usecase/crops/update-crop.usecase';
import { CropEditPresenter } from '../../../adapters/crops/crop-edit.presenter';
import { LOAD_CROP_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/crops/load-crop-for-edit.output-port';
import { UPDATE_CROP_OUTPUT_PORT } from '../../../usecase/crops/update-crop.output-port';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { CropApiGateway } from '../../../adapters/crops/crop-api.gateway';

const initialFormData: CropEditFormData = {
  name: '',
  variety: null,
  area_per_unit: null,
  revenue_per_area: null,
  region: null,
  groups: []
};

const initialControl: CropEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-crop-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule],
  providers: [
    CropEditPresenter,
    LoadCropForEditUseCase,
    UpdateCropUseCase,
    { provide: LOAD_CROP_FOR_EDIT_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: UPDATE_CROP_OUTPUT_PORT, useExisting: CropEditPresenter },
    { provide: CROP_GATEWAY, useClass: CropApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'crops.edit.title' | translate }}</h2>
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <p class="master-error">{{ control.error }}</p>
        } @else {
          <form (ngSubmit)="updateCrop()" #cropForm="ngForm" class="form-card__form">
            <label class="form-card__field">
              {{ 'crops.form.name_label' | translate }}
              <input name="name" [(ngModel)]="control.formData.name" required />
            </label>
            <label class="form-card__field">
              {{ 'crops.form.variety_label' | translate }}
              <input name="variety" [(ngModel)]="control.formData.variety" />
            </label>
            <label class="form-card__field">
              {{ 'crops.form.area_per_unit_label' | translate }}
              <input name="area_per_unit" type="number" step="0.01" [(ngModel)]="control.formData.area_per_unit" />
            </label>
            <label class="form-card__field">
              {{ 'crops.form.revenue_per_area_label' | translate }}
              <input name="revenue_per_area" type="number" step="0.01" [(ngModel)]="control.formData.revenue_per_area" />
            </label>
            <label class="form-card__field">
              {{ 'crops.form.region_label' | translate }}
              <input name="region" [(ngModel)]="control.formData.region" />
            </label>
            @if (control.error) {
              <p class="master-error">{{ control.error }}</p>
            }
            <div class="form-card__actions">
              <button type="submit" class="btn-primary" [disabled]="cropForm.invalid || control.saving">
                {{ 'crops.form.submit_update' | translate }}
              </button>
              <a [routerLink]="['/crops']" class="btn-secondary">{{ 'common.back' | translate }}</a>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrl: './crop-edit.component.css'
})
export class CropEditComponent implements CropEditView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadCropForEditUseCase);
  private readonly updateUseCase = inject(UpdateCropUseCase);
  private readonly presenter = inject(CropEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: CropEditViewState = initialControl;
  get control(): CropEditViewState {
    return this._control;
  }
  set control(value: CropEditViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  private get cropId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.cropId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid crop id.' };
      return;
    }
    this.loadUseCase.execute({ cropId: this.cropId });
  }

  updateCrop(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    this.updateUseCase.execute({
      cropId: this.cropId,
      ...this.control.formData,
      onSuccess: () => this.router.navigate(['/crops', this.cropId])
    });
  }
}
