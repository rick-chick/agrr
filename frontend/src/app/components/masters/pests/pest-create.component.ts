import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PestCreateView, PestCreateViewState, PestCreateFormData } from './pest-create.view';
import { CreatePestUseCase } from '../../../usecase/pests/create-pest.usecase';
import { PestCreatePresenter } from '../../../adapters/pests/pest-create.presenter';
import { CREATE_PEST_OUTPUT_PORT } from '../../../usecase/pests/create-pest.output-port';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';
import { PestApiGateway } from '../../../adapters/pests/pest-api.gateway';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';

const initialFormData: PestCreateFormData = {
  name: '',
  name_scientific: null,
  family: null,
  order: null,
  description: null,
  occurrence_season: null,
  region: null
};

const initialControl: PestCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-pest-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule, RegionSelectComponent],
  providers: [
    PestCreatePresenter,
    CreatePestUseCase,
    { provide: CREATE_PEST_OUTPUT_PORT, useExisting: PestCreatePresenter },
    { provide: PEST_GATEWAY, useClass: PestApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">Create Pest</h2>
        <form (ngSubmit)="createPest()" #pestForm="ngForm" class="form-card__form">
          <label class="form-card__field" for="name">
            <span class="form-card__field-label">Name</span>
            <input id="name" name="name" [(ngModel)]="control.formData.name" required />
          </label>
          <label class="form-card__field" for="name_scientific">
            <span class="form-card__field-label">Scientific Name</span>
            <input id="name_scientific" name="name_scientific" [(ngModel)]="control.formData.name_scientific" />
          </label>
          <label class="form-card__field" for="family">
            <span class="form-card__field-label">Family</span>
            <input id="family" name="family" [(ngModel)]="control.formData.family" />
          </label>
          <label class="form-card__field" for="order">
            <span class="form-card__field-label">Order</span>
            <input id="order" name="order" [(ngModel)]="control.formData.order" />
          </label>
          <label class="form-card__field" for="description">
            <span class="form-card__field-label">Description</span>
            <textarea id="description" name="description" [(ngModel)]="control.formData.description"></textarea>
          </label>
          <label class="form-card__field" for="occurrence_season">
            <span class="form-card__field-label">Occurrence Season</span>
            <input id="occurrence_season" name="occurrence_season" [(ngModel)]="control.formData.occurrence_season" />
          </label>
          <app-region-select
            [region]="control.formData.region"
            (regionChange)="control.formData.region = $event"
          ></app-region-select>
          <div class="form-card__actions">
            <button type="submit" class="btn-primary" [disabled]="pestForm.invalid || control.saving">
              {{ control.saving ? 'Creating...' : 'Create Pest' }}
            </button>
            <a [routerLink]="['/pests']" class="btn-secondary">Back</a>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrl: './pest-create.component.css'
})
export class PestCreateComponent implements PestCreateView, OnInit {
  private readonly router = inject(Router);
  private readonly useCase = inject(CreatePestUseCase);
  private readonly presenter = inject(PestCreatePresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PestCreateViewState = initialControl;
  get control(): PestCreateViewState {
    return this._control;
  }
  set control(value: PestCreateViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
  }

  createPest(): void {
    if (!this.control.formData.name.trim()) return;
    this.control = { ...this.control, saving: true };
    this.useCase.execute({
      ...this.control.formData,
      onSuccess: (pest) => this.router.navigate(['/pests', pest.id])
    });
  }
}