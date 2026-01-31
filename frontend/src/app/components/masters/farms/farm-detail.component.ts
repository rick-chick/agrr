import { Component, OnDestroy, OnInit, inject, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
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
  imports: [CommonModule, RouterLink, FarmMapComponent, TranslateModule, FormsModule],
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
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="master-loading master-error">{{ control.error }}</p>
      } @else if (control.farm) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.farm.name }}</h1>
          <dl class="detail-card__list">
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'farms.show.location' | translate }}</dt>
              <dd class="detail-row__value">{{ control.farm.region ?? '-' }}</dd>
            </div>
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/farms', control.farm.id, 'edit']" class="btn-primary">{{ 'common.edit' | translate }}</a>
            <a [routerLink]="['/farms']" class="btn-secondary">{{ 'farms.show.back_to_list' | translate }}</a>
            <button type="button" class="btn-danger" (click)="confirmDeleteFarm()">{{ 'common.delete' | translate }}</button>
          </div>
        </section>

        @if (control.farm.weather_data_status && control.farm.weather_data_status !== 'completed') {
          <section class="section-card" aria-labelledby="weather-heading">
            <h2 id="weather-heading" class="section-title">{{ 'farms.show.weather_status' | translate }}</h2>
            <p>{{ control.farm.weather_data_status }}</p>
            @if (control.farm.weather_data_status === 'fetching') {
              <p>{{ 'farms.show.weather_progress' | translate }}: {{ control.farm.weather_data_progress ?? 0 }}%</p>
              <progress class="progress-bar" [value]="control.farm.weather_data_progress ?? 0" max="100"></progress>
            }
          </section>
        }

        <section class="section-card" aria-labelledby="map-heading">
          <h2 id="map-heading" class="section-title">{{ 'farms.show.map' | translate }}</h2>
          <app-farm-map
            [latitude]="control.farm.latitude"
            [longitude]="control.farm.longitude"
            [name]="control.farm.name"
          />
        </section>

        <section class="section-card" aria-labelledby="fields-heading">
          <div class="section-card__header-actions">
            <h2 id="fields-heading" class="section-title">{{ 'farms.show.fields' | translate }}</h2>
            <button type="button" class="btn-primary" (click)="openFieldForm()">{{ 'farms.show.add_field' | translate }}</button>
          </div>
          @if (control.fields.length === 0) {
            <p class="fields-empty">{{ 'farms.show.no_fields' | translate }}</p>
            <button type="button" class="btn-primary" (click)="openFieldForm()">{{ 'farms.show.add_first_field' | translate }}</button>
          } @else {
            <ul class="card-list" role="list">
              @for (field of control.fields; track field.id) {
                <li class="card-list__item">
                  <article class="item-card">
                    <div class="item-card__body">
                      <span class="item-card__title">{{ field.name }} ({{ field.area ?? '-' }} ha)</span>
                    </div>
                    <div class="item-card__actions">
                      <button type="button" class="btn-secondary" (click)="openFieldForm(field)">{{ 'common.edit' | translate }}</button>
                      <button type="button" class="btn-danger" (click)="confirmDeleteField(field)">{{ 'common.delete' | translate }}</button>
                    </div>
                  </article>
                </li>
              }
            </ul>
          }
        </section>
      }
    </main>

    <dialog #confirmDialog class="confirm-dialog" (cancel)="closeConfirmDialog()" (close)="closeConfirmDialog()">
      <p class="confirm-dialog__message">{{ confirmMessage }}</p>
      <div class="confirm-dialog__actions">
        <button type="button" class="btn-secondary" (click)="closeConfirmDialog()">{{ 'common.cancel' | translate }}</button>
        <button type="button" class="btn-danger" (click)="executeConfirmedDelete()">{{ 'common.delete' | translate }}</button>
      </div>
    </dialog>

    <dialog #fieldFormDialog class="form-dialog" (cancel)="closeFieldForm()" (close)="closeFieldForm()">
      <h3 class="form-dialog__title">{{ (editingField ? 'farms.show.field_form.edit_title' : 'farms.show.field_form.add_title') | translate }}</h3>
      <form class="form-card__form" (ngSubmit)="submitFieldForm()" #fieldForm="ngForm">
        <div class="form-card__field">
          <label for="field-name">{{ 'farms.show.field_form.name_label' | translate }}</label>
          <input id="field-name" type="text" name="name" [(ngModel)]="fieldFormModel.name" [placeholder]="'farms.show.field_form.name_placeholder' | translate" required>
        </div>
        <div class="form-card__field">
          <label for="field-area">{{ 'farms.show.field_form.area_label' | translate }}</label>
          <input id="field-area" type="number" name="area" step="0.01" [(ngModel)]="fieldFormModel.area" [placeholder]="'farms.show.field_form.area_placeholder' | translate">
        </div>
        <div class="form-card__field">
          <label for="field-cost">{{ 'farms.show.field_form.daily_fixed_cost_label' | translate }}</label>
          <input id="field-cost" type="number" name="daily_fixed_cost" step="0.01" [(ngModel)]="fieldFormModel.daily_fixed_cost" [placeholder]="'farms.show.field_form.daily_fixed_cost_placeholder' | translate">
        </div>
        <div class="form-card__field">
          <label for="field-region">{{ 'farms.show.field_form.region_label' | translate }}</label>
          <input id="field-region" type="text" name="region" [(ngModel)]="fieldFormModel.region" [placeholder]="'farms.show.field_form.region_placeholder' | translate">
        </div>
        <div class="form-card__actions">
          <button type="button" class="btn-secondary" (click)="closeFieldForm()">{{ 'common.cancel' | translate }}</button>
          <button type="submit" class="btn-primary" [disabled]="!fieldForm.valid">{{ (editingField ? 'farms.show.field_form.submit_update' : 'farms.show.field_form.submit_create') | translate }}</button>
        </div>
      </form>
    </dialog>
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
  private readonly translate = inject(TranslateService);

  private channel: Channel | null = null;

  @ViewChild('confirmDialog') confirmDialogRef!: ElementRef<HTMLDialogElement>;
  @ViewChild('fieldFormDialog') fieldFormDialogRef!: ElementRef<HTMLDialogElement>;

  confirmMessage = '';
  pendingDeleteFarm = false;
  pendingDeleteField: Field | null = null;

  editingField: Field | null = null;
  fieldFormModel = {
    name: '',
    area: null as number | null,
    daily_fixed_cost: null as number | null,
    region: ''
  };

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

  reload(): void {
    const farmId = Number(this.route.snapshot.paramMap.get('id'));
    if (farmId) this.load(farmId);
  }

  confirmDeleteFarm(): void {
    this.confirmMessage = this.translate.instant('farms.show.delete_confirm');
    this.pendingDeleteFarm = true;
    this.pendingDeleteField = null;
    this.confirmDialogRef?.nativeElement?.showModal();
  }

  confirmDeleteField(field: Field): void {
    this.confirmMessage = this.translate.instant('farms.show.confirm_delete_field');
    this.pendingDeleteFarm = false;
    this.pendingDeleteField = field;
    this.confirmDialogRef?.nativeElement?.showModal();
  }

  closeConfirmDialog(): void {
    this.pendingDeleteFarm = false;
    this.pendingDeleteField = null;
    this.confirmDialogRef?.nativeElement?.close();
  }

  executeConfirmedDelete(): void {
    if (this.pendingDeleteFarm && this.control.farm) {
      this.closeConfirmDialog();
      this.deleteUseCase.execute({
        farmId: this.control.farm.id,
        onSuccess: () => this.router.navigate(['/farms'])
      });
    } else if (this.pendingDeleteField && this.control.farm) {
      const field = this.pendingDeleteField;
      this.closeConfirmDialog();
      this.deleteFieldUseCase.execute({
        fieldId: field.id,
        farmId: this.control.farm.id
      });
    }
  }

  openFieldForm(field?: Field): void {
    this.editingField = field ?? null;
    if (field) {
      this.fieldFormModel = {
        name: field.name,
        area: field.area,
        daily_fixed_cost: field.daily_fixed_cost,
        region: field.region ?? ''
      };
    } else {
      this.fieldFormModel = {
        name: '',
        area: null,
        daily_fixed_cost: null,
        region: ''
      };
    }
    this.fieldFormDialogRef?.nativeElement?.showModal();
  }

  closeFieldForm(): void {
    this.editingField = null;
    this.fieldFormDialogRef?.nativeElement?.close();
  }

  submitFieldForm(): void {
    if (!this.control.farm) return;

    const { name, area, daily_fixed_cost, region } = this.fieldFormModel;
    if (!name?.trim()) return;

    if (this.editingField) {
      this.updateFieldUseCase.execute({
        fieldId: this.editingField.id,
        payload: {
          name: name.trim(),
          area,
          daily_fixed_cost,
          region: region?.trim() || null
        }
      });
    } else {
      this.createFieldUseCase.execute({
        farmId: this.control.farm.id,
        payload: {
          name: name.trim(),
          area,
          daily_fixed_cost,
          region: region?.trim() || null
        }
      });
    }
    this.closeFieldForm();
  }

  trackByFieldId(_index: number, field: Field): number {
    return field.id;
  }
}
