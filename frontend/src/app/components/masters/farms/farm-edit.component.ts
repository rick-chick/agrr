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
  imports: [CommonModule, FormsModule, RouterLink],
  providers: [
    FarmEditPresenter,
    LoadFarmForEditUseCase,
    UpdateFarmUseCase,
    { provide: LOAD_FARM_FOR_EDIT_OUTPUT_PORT, useExisting: FarmEditPresenter },
    { provide: UPDATE_FARM_OUTPUT_PORT, useExisting: FarmEditPresenter },
    { provide: FARM_GATEWAY, useClass: FarmApiGateway }
  ],
  template: `
    <section class="page">
      <a routerLink="/farms">Back to farms</a>
      <h2>Edit Farm</h2>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <form (ngSubmit)="updateFarm()" #farmForm="ngForm">
          <label>
            Name
            <input name="name" [(ngModel)]="control.formData.name" required />
          </label>
          <label>
            Region
            <input name="region" [(ngModel)]="control.formData.region" required />
          </label>
          <label>
            Latitude
            <input name="latitude" type="number" step="0.000001" [(ngModel)]="control.formData.latitude" required />
          </label>
          <label>
            Longitude
            <input name="longitude" type="number" step="0.000001" [(ngModel)]="control.formData.longitude" required />
          </label>
          <button type="submit" [disabled]="farmForm.invalid || control.saving">Save</button>
        </form>
      }
    </section>
  `
})
export class FarmEditComponent implements FarmEditView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadFarmForEditUseCase);
  private readonly updateUseCase = inject(UpdateFarmUseCase);
  private readonly presenter = inject(FarmEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: FarmEditViewState = initialControl;
  get control(): FarmEditViewState {
    return this._control;
  }
  set control(value: FarmEditViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  private get farmId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.farmId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid farm id.' };
      return;
    }
    this.loadUseCase.execute({ farmId: this.farmId });
  }

  updateFarm(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    this.updateUseCase.execute({
      farmId: this.farmId,
      name: this.control.formData.name,
      region: this.control.formData.region,
      latitude: this.control.formData.latitude,
      longitude: this.control.formData.longitude,
      onSuccess: () => this.router.navigate(['/farms', this.farmId])
    });
  }
}
