import { Component, OnDestroy, OnInit, inject, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { Channel } from 'actioncable';
import { FarmMapComponent } from './farm-map.component';
import { FarmDetailView, FarmDetailViewState } from './farm-detail.view';
import { Field } from '../../../domain/farms/field';
import { AuthService } from '../../../services/auth.service';
import { CurrentUser } from '../../../services/api.service';
import { detectBrowserRegion } from '../../../core/browser-region';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { LoadFarmDetailUseCase } from '../../../usecase/farms/load-farm-detail.usecase';
import { SubscribeFarmWeatherUseCase } from '../../../usecase/farms/subscribe-farm-weather.usecase';
import { DeleteFarmUseCase } from '../../../usecase/farms/delete-farm.usecase';
import { CreateFieldUseCase } from '../../../usecase/farms/create-field.usecase';
import { UpdateFieldUseCase } from '../../../usecase/farms/update-field.usecase';
import { DeleteFieldUseCase } from '../../../usecase/farms/delete-field.usecase';
import {
  CreateFieldPresenter,
  DeleteFieldPresenter,
  FarmDetailPresenter,
  FARM_DETAIL_PROVIDERS,
  UpdateFieldPresenter
} from '../../../usecase/farms/farm-detail.providers';
import { UndoToastService } from '../../../services/undo-toast.service';
import { applyPendingUndoToastViewEffects } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';

const initialControl: FarmDetailViewState = {
  loading: true,
  error: null,
  farm: null,
  fields: [],
  pendingUndoToast: null,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-farm-detail',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    FarmMapComponent,
    TranslateModule,
    FormsModule,
    RegionSelectComponent,
    MasterContextHeaderComponent
  ],
  providers: [...FARM_DETAIL_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
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
              <dd class="detail-row__value">
                @if (control.farm.region) {
                  {{ 'farms.form.region_' + control.farm.region | translate }}
                } @else {
                  {{ 'farms.form.region_blank' | translate }}
                }
              </dd>
            </div>
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/farms', control.farm.id, 'edit']" class="btn-primary">{{ 'common.edit' | translate }}</a>
            <button type="button" class="btn-danger" (click)="deleteFarm()">{{ 'common.delete' | translate }}</button>
          </div>
        </section>

        @if (control.farm.weather_data_status && control.farm.weather_data_status !== 'completed') {
          <section class="section-card" aria-labelledby="weather-heading">
            <h2 id="weather-heading" class="section-title">{{ 'farms.show.weather_status' | translate }}</h2>
            <p>
              {{ ('models.farm.weather_status.' + control.farm.weather_data_status) | translate: { progress: control.farm.weather_data_progress ?? 0 } }}
            </p>
            @if (control.farm.weather_data_status === 'fetching') {
              <p>{{ 'farms.show.weather_progress' | translate }}: {{ control.farm.weather_data_progress ?? 0 }}%</p>
              <progress class="progress-bar" [value]="control.farm.weather_data_progress ?? 0" max="100"></progress>
            }
          </section>
        }

        <section class="section-card" aria-labelledby="map-heading">
          <h2 id="map-heading" class="section-title">{{ 'farms.show.map.title' | translate }}</h2>
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
                      <span class="item-card__title">{{ 'farms.show.field_list_item' | translate: { name: field.name, area: field.area ?? '-' } }}</span>
                    </div>
                    <div class="item-card__actions">
                      <button type="button" class="btn-secondary" (click)="openFieldForm(field)">{{ 'common.edit' | translate }}</button>
                      <button type="button" class="btn-danger" (click)="deleteField(field)">{{ 'common.delete' | translate }}</button>
                    </div>
                  </article>
                </li>
              }
            </ul>
          }
        </section>
      }
    </main>

    <dialog #fieldFormDialog class="form-dialog" (cancel)="closeFieldForm()" (close)="closeFieldForm()">
      <h3 class="form-dialog__title">{{ (editingField ? 'farms.show.field_form.edit_title' : 'farms.show.field_form.add_title') | translate }}</h3>
      <form class="form-card__form" (ngSubmit)="submitFieldForm()" #fieldForm="ngForm">
        <div class="form-card__field">
          <label class="form-card__field-label" for="field-name">{{ 'farms.show.field_form.name_label' | translate }}</label>
          <input id="field-name" type="text" name="name" [(ngModel)]="fieldFormModel.name" [placeholder]="'farms.show.field_form.name_placeholder' | translate" required>
        </div>
        <div class="form-card__field">
          <label class="form-card__field-label" for="field-area">{{ 'farms.show.field_form.area_label' | translate }}</label>
          <input id="field-area" type="number" name="area" step="0.01" min="0" [(ngModel)]="fieldFormModel.area" [placeholder]="'farms.show.field_form.area_placeholder' | translate">
        </div>
        <div class="form-card__field">
          <label class="form-card__field-label" for="field-cost">{{ 'farms.show.field_form.daily_fixed_cost_label' | translate }}</label>
          <input id="field-cost" type="number" name="daily_fixed_cost" step="0.01" min="0" [(ngModel)]="fieldFormModel.daily_fixed_cost" [placeholder]="'farms.show.field_form.daily_fixed_cost_placeholder' | translate">
        </div>
        @if (isAdmin) {
          <app-region-select
            id="field-region"
            [region]="fieldFormModel.region"
            (regionChange)="fieldFormModel.region = $event"
          ></app-region-select>
        }
        <div class="form-card__actions">
          <button type="button" class="btn-secondary" (click)="closeFieldForm()">{{ 'common.cancel' | translate }}</button>
          <button type="submit" class="btn-primary" [disabled]="!fieldForm.valid">{{ (editingField ? 'farms.show.field_form.submit_update' : 'farms.show.field_form.submit_create') | translate }}</button>
        </div>
      </form>
    </dialog>
  `,
  styleUrls: ['./farm-detail.component.css']
})
export class FarmDetailComponent implements FarmDetailView, OnInit, OnDestroy {
  readonly auth = inject(AuthService);
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
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  private channel: Channel | null = null;

  @ViewChild('fieldFormDialog') fieldFormDialogRef!: ElementRef<HTMLDialogElement>;

  editingField: Field | null = null;
  fieldFormModel = {
    name: '',
    area: null as number | null,
    daily_fixed_cost: null as number | null,
    region: null as string | null
  };

  get isAdmin(): boolean {
    return this.auth.user()?.admin ?? false;
  }

  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'farms.index.title', routerLink: ['/farms'] }
    ];
    if (this.control.farm) {
      crumbs.push({ label: this.control.farm.name });
    }
    return crumbs;
  }

  private _control: FarmDetailViewState = initialControl;
  get control(): FarmDetailViewState {
    return this._control;
  }
  set control(value: FarmDetailViewState) {
    const next = applyPendingUndoToastViewEffects(
      applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage }),
      { toast: this.undoToast }
    );
    this._control = next;
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

  deleteFarm(): void {
    if (!this.control.farm) return;
    this.deleteUseCase.execute({
      farmId: this.control.farm.id,
      onSuccess: () => this.router.navigate(['/farms'])
    });
  }

  deleteField(field: Field): void {
    if (!this.control.farm) return;
    this.deleteFieldUseCase.execute({
      fieldId: field.id,
      farmId: this.control.farm.id
    });
  }

  openFieldForm(field?: Field): void {
    this.editingField = field ?? null;
    if (field) {
      this.fieldFormModel = {
        name: field.name,
        area: field.area,
        daily_fixed_cost: field.daily_fixed_cost,
        region: field.region ?? null
      };
    } else {
      this.fieldFormModel = {
        name: '',
        area: null,
        daily_fixed_cost: null,
        region: this.control.farm?.region ?? null
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

    const { name, area, daily_fixed_cost } = this.fieldFormModel;
    if (!name?.trim()) return;

    const region = this.resolveRegionForSubmit();

    if (this.editingField) {
      this.updateFieldUseCase.execute({
        fieldId: this.editingField.id,
        payload: {
          name: name.trim(),
          area,
          daily_fixed_cost,
          region
        }
      });
    } else {
      this.createFieldUseCase.execute({
        farmId: this.control.farm.id,
        payload: {
          name: name.trim(),
          area,
          daily_fixed_cost,
          region
        }
      });
    }
    this.closeFieldForm();
  }

  private resolveRegionForSubmit(): string | null {
    if (this.isAdmin) {
      return this.fieldFormModel.region || null;
    }
    return this.currentUserRegion ?? this.fieldFormModel.region;
  }

  private get currentUserRegion(): string | null {
    const user = this.auth.user() as CurrentUser | null;
    return user?.region ?? detectBrowserRegion();
  }

  trackByFieldId(_index: number, field: Field): number {
    return field.id;
  }
}
