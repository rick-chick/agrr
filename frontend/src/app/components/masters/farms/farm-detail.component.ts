import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Channel } from 'actioncable';
import { FarmMapComponent } from './farm-map.component';
import { FarmDetailView, FarmDetailViewState } from './farm-detail.view';
import { LoadFarmDetailUseCase } from '../../../usecase/farms/load-farm-detail.usecase';
import { SubscribeFarmWeatherUseCase } from '../../../usecase/farms/subscribe-farm-weather.usecase';
import { DeleteFarmUseCase } from '../../../usecase/farms/delete-farm.usecase';
import { FarmDetailPresenter } from '../../../adapters/farms/farm-detail.presenter';
import { LOAD_FARM_DETAIL_OUTPUT_PORT } from '../../../usecase/farms/load-farm-detail.output-port';
import { SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT } from '../../../usecase/farms/subscribe-farm-weather.output-port';
import { DELETE_FARM_OUTPUT_PORT } from '../../../usecase/farms/delete-farm.output-port';
import { FARM_GATEWAY } from '../../../usecase/farms/farm-gateway';
import { FARM_WEATHER_GATEWAY } from '../../../usecase/farms/farm-weather-gateway';
import { FarmApiGateway } from '../../../adapters/farms/farm-api.gateway';
import { FarmWeatherChannelGateway } from '../../../adapters/farms/farm-weather-channel.gateway';

const initialControl: FarmDetailViewState = {
  loading: true,
  error: null,
  farm: null,
  fields: []
};

@Component({
  selector: 'app-farm-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, FarmMapComponent],
  providers: [
    FarmDetailPresenter,
    LoadFarmDetailUseCase,
    SubscribeFarmWeatherUseCase,
    DeleteFarmUseCase,
    { provide: LOAD_FARM_DETAIL_OUTPUT_PORT, useExisting: FarmDetailPresenter },
    { provide: SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT, useExisting: FarmDetailPresenter },
    { provide: DELETE_FARM_OUTPUT_PORT, useExisting: FarmDetailPresenter },
    { provide: FARM_GATEWAY, useClass: FarmApiGateway },
    { provide: FARM_WEATHER_GATEWAY, useClass: FarmWeatherChannelGateway }
  ],
  template: `
    <section class="page">
      <a [routerLink]="['/farms']">Back to farms</a>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else if (control.farm) {
        <h2>{{ control.farm.name }}</h2>
        <p>Location: {{ control.farm.region ?? '-' }}</p>

        @if (control.farm.weather_data_status && control.farm.weather_data_status !== 'completed') {
          <div class="weather-status">
            <p>Weather Data Status: {{ control.farm.weather_data_status }}</p>
            @if (control.farm.weather_data_status === 'fetching') {
              <p>Progress: {{ control.farm.weather_data_progress ?? 0 }}%</p>
              <progress [value]="control.farm.weather_data_progress ?? 0" max="100"></progress>
            }
          </div>
        }

        <div class="actions">
          <a [routerLink]="['/farms', control.farm.id, 'edit']">Edit</a>
          <button type="button" (click)="deleteFarm()">Delete</button>
        </div>

        <app-farm-map
          [latitude]="control.farm.latitude"
          [longitude]="control.farm.longitude"
          [name]="control.farm.name"
        />

        <h3>Fields</h3>
        <ul>
          <li *ngFor="let field of control.fields">{{ field.name }} ({{ field.area }} ha)</li>
        </ul>
      }
    </section>
  `,
  styleUrl: './farm-detail.component.css'
})
export class FarmDetailComponent implements FarmDetailView, OnInit, OnDestroy {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadFarmDetailUseCase);
  private readonly subscribeWeatherUseCase = inject(SubscribeFarmWeatherUseCase);
  private readonly deleteUseCase = inject(DeleteFarmUseCase);
  private readonly presenter = inject(FarmDetailPresenter);

  private channel: Channel | null = null;

  private _control: FarmDetailViewState = initialControl;
  get control(): FarmDetailViewState {
    return this._control;
  }
  set control(value: FarmDetailViewState) {
    this._control = value;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const farmId = Number(this.route.snapshot.paramMap.get('id'));
    if (!farmId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid farm id.' };
      return;
    }
    this.load(farmId);
  }

  ngOnDestroy(): void {
    this.channel?.unsubscribe();
  }

  load(farmId: number): void {
    this.control = { ...this.control, loading: true };
    this.loadUseCase.execute({ farmId });
    this.subscribeWeatherUseCase.execute({
      farmId,
      onSubscribed: (ch) => {
        this.channel = ch;
      }
    });
  }

  deleteFarm(): void {
    if (!this.control.farm) return;
    if (!confirm('Delete this farm?')) return;
    this.deleteUseCase.execute({
      farmId: this.control.farm.id,
      onSuccess: () => this.router.navigate(['/farms'])
    });
  }
}
