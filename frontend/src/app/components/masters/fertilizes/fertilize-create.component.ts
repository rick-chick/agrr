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
    <section class="page">
      <a routerLink="/fertilizes">Back to fertilizes</a>
      <h2>Create Fertilize</h2>
      <form (ngSubmit)="createFertilize()" #fertilizeForm="ngForm">
        <label>
          Name
          <input name="name" [(ngModel)]="control.formData.name" required />
        </label>
        <label>
          Region
          <input name="region" [(ngModel)]="control.formData.region" />
        </label>
        <label>
          N
          <input name="n" type="number" step="0.01" [(ngModel)]="control.formData.n" />
        </label>
        <label>
          P
          <input name="p" type="number" step="0.01" [(ngModel)]="control.formData.p" />
        </label>
        <label>
          K
          <input name="k" type="number" step="0.01" [(ngModel)]="control.formData.k" />
        </label>
        <label>
          Package Size (kg)
          <input name="package_size" type="number" step="0.01" [(ngModel)]="control.formData.package_size" />
        </label>
        <label>
          Description
          <textarea name="description" [(ngModel)]="control.formData.description"></textarea>
        </label>
        <button type="submit" [disabled]="fertilizeForm.invalid || control.saving">Create</button>
        @if (control.error) {
          <p class="error">{{ control.error }}</p>
        }
      </form>
    </section>
  `
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
