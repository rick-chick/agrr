import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FertilizeEditView, FertilizeEditViewState, FertilizeEditFormData } from './fertilize-edit.view';
import { LoadFertilizeForEditUseCase } from '../../../usecase/fertilizes/load-fertilize-for-edit.usecase';
import { UpdateFertilizeUseCase } from '../../../usecase/fertilizes/update-fertilize.usecase';
import { FertilizeEditPresenter } from '../../../adapters/fertilizes/fertilize-edit.presenter';
import { LOAD_FERTILIZE_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/fertilizes/load-fertilize-for-edit.output-port';
import { UPDATE_FERTILIZE_OUTPUT_PORT } from '../../../usecase/fertilizes/update-fertilize.output-port';
import { FERTILIZE_GATEWAY } from '../../../usecase/fertilizes/fertilize-gateway';
import { FertilizeApiGateway } from '../../../adapters/fertilizes/fertilize-api.gateway';

const initialFormData: FertilizeEditFormData = {
  name: '',
  n: null,
  p: null,
  k: null,
  description: null,
  package_size: null,
  region: null
};

const initialControl: FertilizeEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-fertilize-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  providers: [
    FertilizeEditPresenter,
    LoadFertilizeForEditUseCase,
    UpdateFertilizeUseCase,
    { provide: LOAD_FERTILIZE_FOR_EDIT_OUTPUT_PORT, useExisting: FertilizeEditPresenter },
    { provide: UPDATE_FERTILIZE_OUTPUT_PORT, useExisting: FertilizeEditPresenter },
    { provide: FERTILIZE_GATEWAY, useClass: FertilizeApiGateway }
  ],
  template: `
    <section class="page">
      <a routerLink="/fertilizes">Back to fertilizes</a>
      <h2>Edit Fertilize</h2>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <form (ngSubmit)="updateFertilize()" #fertilizeForm="ngForm">
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
          <button type="submit" [disabled]="fertilizeForm.invalid || control.saving">Save</button>
        </form>
      }
    </section>
  `
})
export class FertilizeEditComponent implements FertilizeEditView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadFertilizeForEditUseCase);
  private readonly updateUseCase = inject(UpdateFertilizeUseCase);
  private readonly presenter = inject(FertilizeEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: FertilizeEditViewState = initialControl;
  get control(): FertilizeEditViewState {
    return this._control;
  }
  set control(value: FertilizeEditViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  private get fertilizeId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.fertilizeId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid fertilize id.' };
      return;
    }
    this.loadUseCase.execute({ fertilizeId: this.fertilizeId });
  }

  updateFertilize(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    this.updateUseCase.execute({
      fertilizeId: this.fertilizeId,
      ...this.control.formData,
      onSuccess: () => this.router.navigate(['/fertilizes'])
    });
  }
}
