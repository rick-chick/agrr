import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { CropCreateView, CropCreateViewState, CropCreateFormData } from './crop-create.view';
import { CreateCropUseCase } from '../../../usecase/crops/create-crop.usecase';
import { CropCreatePresenter } from '../../../adapters/crops/crop-create.presenter';
import { CREATE_CROP_OUTPUT_PORT } from '../../../usecase/crops/create-crop.output-port';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { CropApiGateway } from '../../../adapters/crops/crop-api.gateway';

const initialFormData: CropCreateFormData = {
  name: '',
  variety: null,
  area_per_unit: null,
  revenue_per_area: null,
  region: null,
  groups: []
};

const initialControl: CropCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-crop-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule],
  providers: [
    CropCreatePresenter,
    CreateCropUseCase,
    { provide: CREATE_CROP_OUTPUT_PORT, useExisting: CropCreatePresenter },
    { provide: CROP_GATEWAY, useClass: CropApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'crops.new.title' | translate }}</h2>
        <form (ngSubmit)="createCrop()" #cropForm="ngForm" class="form-card__form">
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
          <div class="form-card__actions">
            <button type="submit" class="btn-primary" [disabled]="cropForm.invalid || control.saving">
              {{ 'crops.form.submit_create' | translate }}
            </button>
            <a [routerLink]="['/crops']" class="btn-secondary">{{ 'common.back' | translate }}</a>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrl: './crop-create.component.css'
})
export class CropCreateComponent implements CropCreateView, OnInit {
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateCropUseCase);
  private readonly presenter = inject(CropCreatePresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: CropCreateViewState = initialControl;
  get control(): CropCreateViewState {
    return this._control;
  }
  set control(value: CropCreateViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
  }

  createCrop(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    this.useCase.execute({
      ...this.control.formData,
      onSuccess: () => this.router.navigate(['/crops'])
    });
  }
}
