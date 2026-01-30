import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { FarmCreateView, FarmCreateViewState, FarmCreateFormData } from './farm-create.view';
import { CreateFarmUseCase } from '../../../usecase/farms/create-farm.usecase';
import { FarmCreatePresenter } from '../../../adapters/farms/farm-create.presenter';
import { CREATE_FARM_OUTPUT_PORT } from '../../../usecase/farms/create-farm.output-port';
import { FARM_GATEWAY } from '../../../usecase/farms/farm-gateway';
import { FarmApiGateway } from '../../../adapters/farms/farm-api.gateway';

const initialFormData: FarmCreateFormData = {
  name: '',
  region: '',
  latitude: 0,
  longitude: 0
};

const initialControl: FarmCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-farm-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  providers: [
    FarmCreatePresenter,
    CreateFarmUseCase,
    { provide: CREATE_FARM_OUTPUT_PORT, useExisting: FarmCreatePresenter },
    { provide: FARM_GATEWAY, useClass: FarmApiGateway }
  ],
  template: `
    <section class="page">
      <a routerLink="/farms">Back to farms</a>
      <h2>Create Farm</h2>
      <form (ngSubmit)="createFarm()" #farmForm="ngForm">
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
        <button type="submit" [disabled]="farmForm.invalid || control.saving">Create</button>
        @if (control.error) {
          <p class="error">{{ control.error }}</p>
        }
      </form>
    </section>
  `
})
export class FarmCreateComponent implements FarmCreateView, OnInit {
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateFarmUseCase);
  private readonly presenter = inject(FarmCreatePresenter);

  private _control: FarmCreateViewState = initialControl;
  get control(): FarmCreateViewState {
    return this._control;
  }
  set control(value: FarmCreateViewState) {
    this._control = value;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
  }

  createFarm(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    this.useCase.execute({
      name: this.control.formData.name,
      region: this.control.formData.region,
      latitude: this.control.formData.latitude,
      longitude: this.control.formData.longitude,
      onSuccess: (farm) => this.router.navigate(['/farms', farm.id])
    });
  }
}
