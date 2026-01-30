import { Component, OnDestroy, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Channel } from 'actioncable';
import { FarmMapComponent } from './farm-map.component';
import { FarmDetailView, FarmDetailViewState } from './farm-detail.view';
import { Field } from '../../../domain/farms/field';
import { LoadFarmDetailUseCase } from '../../../usecase/farms/load-farm-detail.usecase';
import { SubscribeFarmWeatherUseCase } from '../../../usecase/farms/subscribe-farm-weather.usecase';
import { DeleteFarmUseCase } from '../../../usecase/farms/delete-farm.usecase';
import { CreateFieldUseCase } from '../../../usecase/farms/create-field.usecase';
import { UpdateFieldUseCase } from '../../../usecase/farms/update-field.usecase';
import { DeleteFieldUseCase } from '../../../usecase/farms/delete-field.usecase';
import { FarmDetailPresenter } from '../../../adapters/farms/farm-detail.presenter';
import { CreateFieldPresenter } from '../../../adapters/farms/create-field.presenter';
import { UpdateFieldPresenter } from '../../../adapters/farms/update-field.presenter';
import { DeleteFieldPresenter } from '../../../adapters/farms/delete-field.presenter';
import { LOAD_FARM_DETAIL_OUTPUT_PORT } from '../../../usecase/farms/load-farm-detail.output-port';
import { SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT } from '../../../usecase/farms/subscribe-farm-weather.output-port';
import { DELETE_FARM_OUTPUT_PORT } from '../../../usecase/farms/delete-farm.output-port';
import { CREATE_FIELD_OUTPUT_PORT } from '../../../usecase/farms/create-field.output-port';
import { UPDATE_FIELD_OUTPUT_PORT } from '../../../usecase/farms/update-field.output-port';
import { DELETE_FIELD_OUTPUT_PORT } from '../../../usecase/farms/delete-field.output-port';
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
    CreateFieldPresenter,
    CreateFieldUseCase,
    UpdateFieldPresenter,
    UpdateFieldUseCase,
    DeleteFieldPresenter,
    DeleteFieldUseCase,
    { provide: LOAD_FARM_DETAIL_OUTPUT_PORT, useExisting: FarmDetailPresenter },
    { provide: SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT, useExisting: FarmDetailPresenter },
    { provide: DELETE_FARM_OUTPUT_PORT, useExisting: FarmDetailPresenter },
    { provide: CREATE_FIELD_OUTPUT_PORT, useExisting: CreateFieldPresenter },
    { provide: UPDATE_FIELD_OUTPUT_PORT, useExisting: UpdateFieldPresenter },
    { provide: DELETE_FIELD_OUTPUT_PORT, useExisting: DeleteFieldPresenter },
    { provide: FARM_GATEWAY, useClass: FarmApiGateway },
    { provide: FARM_WEATHER_GATEWAY, useClass: FarmWeatherChannelGateway }
  ],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">Loading...</p>
      } @else if (control.error) {
        <p class="master-error">{{ control.error }}</p>
      } @else if (control.farm) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.farm.name }}</h1>
          <dl class="detail-card__list">
            <div class="detail-row">
              <dt class="detail-row__term">Location</dt>
              <dd class="detail-row__value">{{ control.farm.region ?? '-' }}</dd>
            </div>
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/farms']" class="btn-secondary">Back to farms</a>
            <a [routerLink]="['/farms', control.farm.id, 'edit']" class="btn-secondary">Edit</a>
            <button type="button" class="btn-danger" (click)="deleteFarm()">Delete</button>
          </div>
        </section>

        @if (control.farm.weather_data_status && control.farm.weather_data_status !== 'completed') {
          <section class="section-card" aria-labelledby="weather-heading">
            <h2 id="weather-heading" class="section-title">Weather Data Status</h2>
            <p>{{ control.farm.weather_data_status }}</p>
            @if (control.farm.weather_data_status === 'fetching') {
              <p>Progress: {{ control.farm.weather_data_progress ?? 0 }}%</p>
              <progress [value]="control.farm.weather_data_progress ?? 0" max="100"></progress>
            }
          </section>
        }

        <section class="section-card" aria-labelledby="map-heading">
          <h2 id="map-heading" class="section-title">Map</h2>
          <app-farm-map
            [latitude]="control.farm.latitude"
            [longitude]="control.farm.longitude"
            [name]="control.farm.name"
          />
        </section>

        <section class="section-card" aria-labelledby="fields-heading">
          <h2 id="fields-heading" class="section-title">Fields</h2>
          <div class="list-item-actions field-actions-bar">
            <button type="button" class="btn-primary" (click)="addField()">Add Field</button>
          </div>
          <ul class="card-list" role="list">
            @for (field of control.fields; track field.id) {
              <li class="card-list__item">
                <span class="item-card__title">{{ field.name }} ({{ field.area }} ha)</span>
                <div class="list-item-actions">
                  <button type="button" class="btn-secondary btn-sm" (click)="editField(field)">Edit</button>
                  <button type="button" class="btn-danger btn-sm" (click)="deleteField(field)">Delete</button>
                </div>
              </li>
            }
          </ul>
        </section>
      }
    </main>
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
  private readonly createFieldUseCase = inject(CreateFieldUseCase);
  private readonly updateFieldUseCase = inject(UpdateFieldUseCase);
  private readonly deleteFieldUseCase = inject(DeleteFieldUseCase);
  private readonly createFieldPresenter = inject(CreateFieldPresenter);
  private readonly updateFieldPresenter = inject(UpdateFieldPresenter);
  private readonly deleteFieldPresenter = inject(DeleteFieldPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private channel: Channel | null = null;

  private _control: FarmDetailViewState = initialControl;
  get control(): FarmDetailViewState {
    return this._control;
  }
  set control(value: FarmDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.createFieldPresenter.setView(this);
    this.updateFieldPresenter.setView(this);
    this.deleteFieldPresenter.setView(this);
    const farmId = Number(this.route.snapshot.paramMap.get('id'));
    if (!farmId) {
      // Presenter will handle invalid farm id error
      return;
    }
    this.load(farmId);
  }

  ngOnDestroy(): void {
    this.channel?.unsubscribe();
  }

  load(farmId: number): void {
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
    this.deleteUseCase.execute({
      farmId: this.control.farm.id,
      onSuccess: () => this.router.navigate(['/farms'])
    });
  }

  addField(): void {
    const name = prompt('Field name:');
    if (!name) return;

    const areaStr = prompt('Area (ha):');
    const area = areaStr ? parseFloat(areaStr) : null;

    const costStr = prompt('Daily fixed cost:');
    const dailyFixedCost = costStr ? parseFloat(costStr) : null;

    const region = prompt('Region:');

    if (!this.control.farm) return;

    this.createFieldUseCase.execute({
      farmId: this.control.farm.id,
      payload: {
        name,
        area,
        daily_fixed_cost: dailyFixedCost,
        region: region || null
      }
    });
  }

  editField(field: Field): void {
    const name = prompt('Field name:', field.name);
    if (name === null) return; // Cancelled

    const areaStr = prompt('Area (ha):', field.area?.toString() || '');
    const area = areaStr ? parseFloat(areaStr) : null;

    const costStr = prompt('Daily fixed cost:', field.daily_fixed_cost?.toString() || '');
    const dailyFixedCost = costStr ? parseFloat(costStr) : null;

    const region = prompt('Region:', field.region || '');

    this.updateFieldUseCase.execute({
      fieldId: field.id,
      payload: {
        name: name || field.name,
        area,
        daily_fixed_cost: dailyFixedCost,
        region: region || null
      }
    });
  }

  deleteField(field: Field): void {
    if (!this.control.farm) return;

    this.deleteFieldUseCase.execute({
      fieldId: field.id,
      farmId: this.control.farm.id
    });
  }

  trackByFieldId(_index: number, field: Field): number {
    return field.id;
  }
}
