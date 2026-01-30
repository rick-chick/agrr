import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PestEditView, PestEditViewState, PestEditFormData } from './pest-edit.view';
import { LoadPestForEditUseCase } from '../../../usecase/pests/load-pest-for-edit.usecase';
import { UpdatePestUseCase } from '../../../usecase/pests/update-pest.usecase';
import { PestEditPresenter } from '../../../adapters/pests/pest-edit.presenter';
import { LOAD_PEST_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/pests/load-pest-for-edit.output-port';
import { UPDATE_PEST_OUTPUT_PORT } from '../../../usecase/pests/update-pest.output-port';
import { PEST_GATEWAY } from '../../../usecase/pests/pest-gateway';
import { PestApiGateway } from '../../../adapters/pests/pest-api.gateway';

const initialFormData: PestEditFormData = {
  name: '',
  name_scientific: null,
  family: null,
  order: null,
  description: null,
  occurrence_season: null,
  region: null
};

const initialControl: PestEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-pest-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule],
  providers: [
    PestEditPresenter,
    LoadPestForEditUseCase,
    UpdatePestUseCase,
    { provide: LOAD_PEST_FOR_EDIT_OUTPUT_PORT, useExisting: PestEditPresenter },
    { provide: UPDATE_PEST_OUTPUT_PORT, useExisting: PestEditPresenter },
    { provide: PEST_GATEWAY, useClass: PestApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">Edit Pest</h2>
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else if (control.error) {
          <p class="master-error">{{ control.error }}</p>
        } @else {
          <form (ngSubmit)="updatePest()" #pestForm="ngForm" class="form-card__form">
            <label class="form-card__field">
              Name
              <input name="name" [(ngModel)]="control.formData.name" required />
            </label>
            <label class="form-card__field">
              Scientific Name
              <input name="name_scientific" [(ngModel)]="control.formData.name_scientific" />
            </label>
            <label class="form-card__field">
              Family
              <input name="family" [(ngModel)]="control.formData.family" />
            </label>
            <label class="form-card__field">
              Order
              <input name="order" [(ngModel)]="control.formData.order" />
            </label>
            <label class="form-card__field">
              Description
              <textarea name="description" [(ngModel)]="control.formData.description"></textarea>
            </label>
            <label class="form-card__field">
              Occurrence Season
              <input name="occurrence_season" [(ngModel)]="control.formData.occurrence_season" />
            </label>
            <label class="form-card__field">
              Region
              <input name="region" [(ngModel)]="control.formData.region" />
            </label>
            @if (control.error) {
              <p class="master-error">{{ control.error }}</p>
            }
            <div class="form-card__actions">
              <button type="submit" class="btn-primary" [disabled]="pestForm.invalid || control.saving">
                {{ control.saving ? 'Updating...' : 'Update Pest' }}
              </button>
              <a [routerLink]="['/pests']" class="btn-secondary">Back</a>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrl: './pest-edit.component.css'
})
export class PestEditComponent implements PestEditView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadPestForEditUseCase);
  private readonly updateUseCase = inject(UpdatePestUseCase);
  private readonly presenter = inject(PestEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PestEditViewState = initialControl;
  get control(): PestEditViewState {
    return this._control;
  }
  set control(value: PestEditViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const pestId = Number(this.route.snapshot.paramMap.get('id'));
    if (!pestId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid pest id.' };
      return;
    }
    this.load(pestId);
  }

  load(pestId: number): void {
    this.control = { ...this.control, loading: true };
    this.loadUseCase.execute({ pestId });
  }

  updatePest(): void {
    const pestId = Number(this.route.snapshot.paramMap.get('id'));
    if (!pestId || !this.control.formData.name.trim()) return;
    this.control = { ...this.control, saving: true };
    this.updateUseCase.execute({
      pestId,
      ...this.control.formData,
      onSuccess: (pest) => this.router.navigate(['/pests', pest.id])
    });
  }
}