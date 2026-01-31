import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { FertilizeCreateView, FertilizeCreateViewState, FertilizeCreateFormData } from './fertilize-create.view';
import { CreateFertilizeUseCase } from '../../../usecase/fertilizes/create-fertilize.usecase';
import { FertilizeCreatePresenter } from '../../../adapters/fertilizes/fertilize-create.presenter';
import { CREATE_FERTILIZE_OUTPUT_PORT } from '../../../usecase/fertilizes/create-fertilize.output-port';
import { FERTILIZE_GATEWAY } from '../../../usecase/fertilizes/fertilize-gateway';
import { FertilizeApiGateway } from '../../../adapters/fertilizes/fertilize-api.gateway';

const initialFormData: FertilizeCreateFormData = {
  name: '',
  n: null,
  p: null,
  k: null,
  description: null,
  package_size: null,
  region: null
};

const initialControl: FertilizeCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-fertilize-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  providers: [
    FertilizeCreatePresenter,
    CreateFertilizeUseCase,
    { provide: CREATE_FERTILIZE_OUTPUT_PORT, useExisting: FertilizeCreatePresenter },
    { provide: FERTILIZE_GATEWAY, useClass: FertilizeApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">Create Fertilize</h2>
        <form (ngSubmit)="createFertilize()" #fertilizeForm="ngForm" class="form-card__form">
          <label for="name" class="form-card__field">
            <span class="form-card__field-label">Name</span>
            <input id="name" name="name" [(ngModel)]="control.formData.name" required />
          </label>
          <label for="region" class="form-card__field">
            <span class="form-card__field-label">Region</span>
            <input id="region" name="region" [(ngModel)]="control.formData.region" />
          </label>
          <label for="n" class="form-card__field">
            <span class="form-card__field-label">N</span>
            <input id="n" name="n" type="number" step="0.01" [(ngModel)]="control.formData.n" />
          </label>
          <label for="p" class="form-card__field">
            <span class="form-card__field-label">P</span>
            <input id="p" name="p" type="number" step="0.01" [(ngModel)]="control.formData.p" />
          </label>
          <label for="k" class="form-card__field">
            <span class="form-card__field-label">K</span>
            <input id="k" name="k" type="number" step="0.01" [(ngModel)]="control.formData.k" />
          </label>
          <label for="package_size" class="form-card__field">
            <span class="form-card__field-label">Package Size (kg)</span>
            <input id="package_size" name="package_size" type="number" step="0.01" [(ngModel)]="control.formData.package_size" />
          </label>
          <label for="description" class="form-card__field">
            <span class="form-card__field-label">Description</span>
            <textarea id="description" name="description" [(ngModel)]="control.formData.description"></textarea>
          </label>
          <div class="form-card__actions">
            <button type="submit" class="btn-primary" [disabled]="fertilizeForm.invalid || control.saving">Create</button>
            <a routerLink="/fertilizes" class="btn-secondary">Back to fertilizes</a>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrl: './fertilize-create.component.css'
})
export class FertilizeCreateComponent implements FertilizeCreateView, OnInit {
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateFertilizeUseCase);
  private readonly presenter = inject(FertilizeCreatePresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: FertilizeCreateViewState = initialControl;
  get control(): FertilizeCreateViewState {
    return this._control;
  }
  set control(value: FertilizeCreateViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
  }

  createFertilize(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    this.useCase.execute({
      ...this.control.formData,
      onSuccess: () => this.router.navigate(['/fertilizes'])
    });
  }
}
