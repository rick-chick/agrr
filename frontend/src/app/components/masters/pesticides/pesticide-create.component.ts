import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PesticideCreateView, PesticideCreateViewState, PesticideCreateFormData } from './pesticide-create.view';
import { CreatePesticideUseCase } from '../../../usecase/pesticides/create-pesticide.usecase';
import { PesticideCreatePresenter } from '../../../adapters/pesticides/pesticide-create.presenter';
import { CREATE_PESTICIDE_OUTPUT_PORT } from '../../../usecase/pesticides/create-pesticide.output-port';
import { PESTICIDE_GATEWAY } from '../../../usecase/pesticides/pesticide-gateway';
import { PesticideApiGateway } from '../../../adapters/pesticides/pesticide-api.gateway';
import { Crop } from '../../../domain/crops/crop';
import { Pest } from '../../../domain/pests/pest';
import { CROP_GATEWAY } from '../../../usecase/crops/crop-gateway';
import { CropApiGateway } from '../../../adapters/crops/crop-api.gateway';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';
import { PestApiGateway } from '../../../adapters/pests/pest-api.gateway';

const initialFormData: PesticideCreateFormData = {
  name: '',
  active_ingredient: null,
  description: null,
  crop_id: 0,
  pest_id: 0,
  region: null
};

const initialControl: PesticideCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-pesticide-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule],
  providers: [
    PesticideCreatePresenter,
    CreatePesticideUseCase,
    { provide: CREATE_PESTICIDE_OUTPUT_PORT, useExisting: PesticideCreatePresenter },
    { provide: PESTICIDE_GATEWAY, useClass: PesticideApiGateway },
    { provide: CROP_GATEWAY, useClass: CropApiGateway },
    { provide: PEST_GATEWAY, useClass: PestApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">Create Pesticide</h2>
        <form (ngSubmit)="createPesticide()" #pesticideForm="ngForm" class="form-card__form">
          <label class="form-card__field">
            Name
            <input name="name" [(ngModel)]="control.formData.name" required />
          </label>
          <label class="form-card__field">
            Active Ingredient
            <input name="active_ingredient" [(ngModel)]="control.formData.active_ingredient" />
          </label>
          <label class="form-card__field">
            Description
            <textarea name="description" [(ngModel)]="control.formData.description"></textarea>
          </label>
          <label class="form-card__field">
            Crop
            <select name="crop_id" [(ngModel)]="control.formData.crop_id" required>
              <option [value]="0">-- Select Crop --</option>
              <option *ngFor="let crop of crops" [value]="crop.id">{{ crop.name }}</option>
            </select>
          </label>
          <label class="form-card__field">
            Pest
            <select name="pest_id" [(ngModel)]="control.formData.pest_id" required>
              <option [value]="0">-- Select Pest --</option>
              <option *ngFor="let pest of pests" [value]="pest.id">{{ pest.name }}</option>
            </select>
          </label>
          <label class="form-card__field">
            Region
            <input name="region" [(ngModel)]="control.formData.region" />
          </label>
          <div class="form-card__actions">
            <button type="submit" class="btn-primary" [disabled]="pesticideForm.invalid || control.saving || control.formData.crop_id === 0 || control.formData.pest_id === 0">
              {{ control.saving ? 'Creating...' : 'Create Pesticide' }}
            </button>
            <a [routerLink]="['/pesticides']" class="btn-secondary">Back</a>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrl: './pesticide-create.component.css'
})
export class PesticideCreateComponent implements PesticideCreateView, OnInit {
  private readonly router = inject(Router);
  private readonly useCase = inject(CreatePesticideUseCase);
  private readonly presenter = inject(PesticideCreatePresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly cropGateway = inject(CROP_GATEWAY);
  private readonly pestGateway = inject(PEST_GATEWAY);

  crops: Crop[] = [];
  pests: Pest[] = [];

  private _control: PesticideCreateViewState = initialControl;
  get control(): PesticideCreateViewState {
    return this._control;
  }
  set control(value: PesticideCreateViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.loadCropsAndPests();
  }

  private loadCropsAndPests(): void {
    this.cropGateway.list().subscribe(crops => this.crops = crops);
    this.pestGateway.list().subscribe(pests => this.pests = pests);
  }

  createPesticide(): void {
    if (!this.control.formData.name.trim() || this.control.formData.crop_id === 0 || this.control.formData.pest_id === 0) return;
    this.control = { ...this.control, saving: true };
    this.useCase.execute({
      ...this.control.formData,
      onSuccess: (pesticide) => this.router.navigate(['/pesticides', pesticide.id])
    });
  }
}