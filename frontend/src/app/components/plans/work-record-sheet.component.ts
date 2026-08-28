import {
  ChangeDetectorRef,
  Component,
  ElementRef,
  EventEmitter,
  Input,
  OnInit,
  Output,
  ViewChild,
  inject
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, NgForm } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { localTodayIso } from '../../core/local-today';
import { getApiBaseUrl } from '../../core/api-base-url';
import {
  MAX_WORK_RECORD_PHOTOS,
  WORK_RECORD_PHOTO_ACCEPT,
  WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_SHEET,
  WORK_RECORD_PHOTO_THUMB_WIDTH_PX_SHEET
} from '../../domain/plans/work-record-photo.constants';
import { FieldSchedule } from '../../models/plans/task-schedule';
import { WorkRecord } from '../../models/plans/work-record';
import { WorkRecordSheetPresenter } from '../../adapters/plans/work-record-sheet.presenter';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';
import { applyWorkRecordSheetViewEffects } from './work-record-sheet-view.effects';
import {
  resolveCropIdForFieldCultivation,
  scheduleCategoryFromTaskType
} from '../../domain/work-schedule/work-record-sheet-schedule';
import { LoadAgriculturalTaskListUseCase } from '../../usecase/agricultural-tasks/load-agricultural-task-list.usecase';
import { LoadFertilizeListUseCase } from '../../usecase/fertilizes/load-fertilize-list.usecase';
import { LoadCropPesticideListUseCase } from '../../usecase/pesticides/load-crop-pesticide-list.usecase';
import { SaveWorkRecordSheetUseCase } from '../../usecase/plans/save-work-record-sheet.usecase';
import { DeleteWorkRecordUseCase } from '../../usecase/plans/delete-work-record.usecase';
import { PreviewWorkRecordClimateUseCase } from '../../usecase/plans/preview-work-record-climate/preview-work-record-climate.usecase';
import { formatVarianceGddDelta } from '../../domain/plans/work-record-variance';
import {
  computeWorkRecordAmountDiff,
  isAmountTrackedScheduleCategory,
  WorkRecordAmountDiff
} from '../../domain/work-schedule/work-record-amount-diff';
import { isHarvestTaskItem, isHarvestWorkRecord } from '../../domain/work-schedule/work-row-harvest';
import {
  mapFormToCreateRequest,
  mapFormToUpdateRequest
} from '../../usecase/plans/work-record-form.mapper';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import {
  WorkRecordSheetExistingPhoto,
  WorkRecordSheetFormState,
  WorkRecordSheetPendingPhoto,
  WorkRecordSheetSavedEvent,
  WorkRecordSheetTaskChip,
  WorkRecordSheetView,
  WorkRecordSheetViewState,
  WorkRecordScheduleCategory
} from './work-record-sheet.view';
import { WORK_RECORD_SHEET_PROVIDERS } from '../../usecase/plans/work-record-sheet.providers';

function emptyClimatePreview() {
  return {
    gddAtActual: null,
    weatherDate: null,
    temperatureMax: null,
    temperatureMin: null,
    temperatureMean: null,
    plannedGdd: null,
    gddDelta: null,
    loading: false
  };
}

function emptyForm(): WorkRecordSheetFormState {
  return {
    name: '',
    actual_date: localTodayIso(),
    amount: '',
    amount_unit: '',
    time_spent_minutes: '',
    notes: '',
    field_cultivation_id: null,
    fieldName: '',
    cropName: '',
    task_schedule_item_id: null,
    work_record_id: null,
    agricultural_task_id: null,
    fertilize_id: null,
    pesticide_id: null,
    updated_at: ''
  };
}

const initialControl: WorkRecordSheetViewState = {
  mode: 'create-adhoc',
  submitting: false,
  error: null,
  fieldErrors: {},
  form: emptyForm(),
  fieldOptions: [],
  scheduleCategory: null,
  cropId: null,
  fertilizeOptions: [],
  pesticideOptions: [],
  loadingFertilizeOptions: false,
  loadingPesticideOptions: false,
  harvestContext: false,
  plannedAmount: '',
  plannedAmountUnit: '',
  climatePreview: emptyClimatePreview(),
  showDetails: false,
  taskChips: [],
  loadingTaskChips: false,
  selectedTaskId: null,
  pendingToast: null,
  saveToastContext: null,
  pendingUndoToast: null,
  existingPhotos: [],
  pendingPhotos: [],
  photoError: null
};

@Component({
  selector: 'app-work-record-sheet',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule, RouterLink],
  providers: [...WORK_RECORD_SHEET_PROVIDERS],
  template: `
    <dialog #sheetDialog class="form-dialog" (cancel)="close()" (close)="onDialogClose()">
      <h3 class="form-dialog__title">
        @if (control.mode === 'edit') {
          {{ 'plans.work_records.sheet.edit_title' | translate }}
        } @else {
          {{ 'plans.work.sheet.title' | translate }}
        }
      </h3>

      @if (control.error) {
        <div class="page-alert-error" role="alert">
          <p>{{ control.error | translate }}</p>
        </div>
      }

      <form class="form-card__form" (ngSubmit)="submit()" #recordForm="ngForm">
        @if (control.mode === 'create-from-item') {
          <div class="form-card__field">
            <span class="form-card__label">{{ 'plans.work.sheet.name' | translate }}</span>
            <p class="work-record-sheet__readonly">{{ control.form.name }}</p>
          </div>
          <div class="form-card__field">
            <span class="form-card__label">{{ 'plans.work.sheet.field' | translate }}</span>
            <p class="work-record-sheet__readonly">{{ control.form.fieldName }} {{ control.form.cropName }}</p>
          </div>
        } @else if (control.mode === 'create-adhoc') {
          <div class="form-card__field">
            <span class="form-card__label" id="wr-task-picker-label">{{
              'plans.work.sheet.task_picker' | translate
            }}</span>
            @if (control.loadingTaskChips) {
              <p class="work-record-sheet__hint">{{ 'common.loading' | translate }}</p>
            } @else {
              <div
                class="work-record-sheet__chips"
                role="listbox"
                aria-labelledby="wr-task-picker-label"
              >
                @for (chip of control.taskChips; track chip.id) {
                  <button
                    type="button"
                    class="work-record-sheet__chip"
                    role="option"
                    [class.work-record-sheet__chip--selected]="control.selectedTaskId === chip.id"
                    [attr.aria-selected]="control.selectedTaskId === chip.id"
                    (click)="selectTaskChip(chip)"
                  >
                    {{ chip.name }}
                  </button>
                }
                <button
                  type="button"
                  class="work-record-sheet__chip work-record-sheet__chip--other"
                  role="option"
                  [class.work-record-sheet__chip--selected]="control.selectedTaskId === 'other'"
                  [attr.aria-selected]="control.selectedTaskId === 'other'"
                  (click)="selectOtherTask()"
                >
                  {{ 'plans.work.sheet.task_other' | translate }}
                </button>
              </div>
            }
            @if (control.selectedTaskId === 'other') {
              <input
                id="wr-name"
                class="work-record-sheet__other-name"
                type="text"
                name="name"
                [(ngModel)]="control.form.name"
                [attr.placeholder]="'plans.work.sheet.name' | translate"
              />
            }
            @if (fieldError('name')) {
              <p class="form-card__error">{{ fieldError('name') | translate }}</p>
            }
          </div>
        } @else {
          <div class="form-card__field">
            <label for="wr-name">{{ 'plans.work.sheet.name' | translate }}</label>
            <input
              id="wr-name"
              type="text"
              name="name"
              [(ngModel)]="control.form.name"
              required
            />
            @if (fieldError('name')) {
              <p class="form-card__error">{{ fieldError('name') | translate }}</p>
            }
          </div>
        }

        <div class="form-card__field">
          <label for="wr-date">{{ 'plans.work.sheet.actual_date' | translate }}</label>
          <input
            id="wr-date"
            type="date"
            name="actual_date"
            [(ngModel)]="control.form.actual_date"
            (ngModelChange)="onClimateInputsChanged()"
            required
          />
          @if (fieldError('actual_date')) {
            <p class="form-card__error">{{ fieldError('actual_date') | translate }}</p>
          }
        </div>

        @if (control.mode === 'create-adhoc') {
          <div class="form-card__field">
            <label for="wr-field">{{ 'plans.work.sheet.field_select' | translate }}</label>
            <select
              id="wr-field"
              name="field_cultivation_id"
              [(ngModel)]="control.form.field_cultivation_id"
              (ngModelChange)="onFieldCultivationChanged($event)"
            >
              <option [ngValue]="null">{{ 'plans.work.sheet.field_optional' | translate }}</option>
              @for (field of control.fieldOptions; track field.field_cultivation_id) {
                <option [ngValue]="field.field_cultivation_id">
                  {{ field.name }} {{ field.crop_name }}
                </option>
              }
            </select>
          </div>
        } @else if (control.mode === 'edit') {
          <div class="form-card__field">
            <span class="form-card__label">{{ 'plans.work.sheet.field' | translate }}</span>
            <p class="work-record-sheet__readonly">
              @if (control.form.fieldName) {
                {{ control.form.fieldName }} {{ control.form.cropName }}
              } @else {
                {{ 'plans.work_records.badge.adhoc' | translate }}
              }
            </p>
          </div>
        }

        @if (control.mode !== 'edit') {
          <button
            type="button"
            class="work-record-sheet__details-toggle"
            [attr.aria-expanded]="control.showDetails"
            (click)="toggleDetails()"
          >
            {{
              (control.showDetails ? 'plans.work.sheet.hide_details' : 'plans.work.sheet.show_details')
                | translate
            }}
          </button>
        }

        @if (control.mode === 'edit' || control.showDetails) {
          @if (isAmountTrackedScheduleCategory(control.scheduleCategory)) {
            <div class="form-card__field">
              <span class="form-card__label">{{
                'plans.work.sheet.' + control.scheduleCategory + '.planned_amount' | translate
              }}</span>
              <p class="work-record-sheet__readonly">
                @if (control.plannedAmount) {
                  {{ control.plannedAmount }} {{ control.plannedAmountUnit }}
                } @else {
                  {{
                    'plans.work.sheet.' + control.scheduleCategory + '.planned_amount_empty'
                      | translate
                  }}
                }
              </p>
            </div>
          }

          <div
            class="form-card__field form-card__field--row"
            [class.form-card__field--harvest-yield]="control.harvestContext"
          >
            <div>
              <label for="wr-amount">
                @if (isAmountTrackedScheduleCategory(control.scheduleCategory)) {
                  {{
                    'plans.work.sheet.' + control.scheduleCategory + '.actual_amount' | translate
                  }}
                } @else if (control.harvestContext) {
                  {{ 'plans.work.sheet.harvest.yield_amount' | translate }}
                } @else {
                  {{ 'plans.work.sheet.amount' | translate }}
                }
              </label>
              <input
                id="wr-amount"
                type="text"
                name="amount"
                class="work-record-sheet__yield-input"
                [class.work-record-sheet__yield-input--emphasized]="control.harvestContext"
                [(ngModel)]="control.form.amount"
                (ngModelChange)="onAmountChanged()"
              />
            </div>
            <div>
              <label for="wr-unit">
                @if (control.harvestContext) {
                  {{ 'plans.work.sheet.harvest.yield_unit' | translate }}
                } @else {
                  {{ 'plans.work.sheet.amount_unit' | translate }}
                }
              </label>
              <input
                id="wr-unit"
                type="text"
                name="amount_unit"
                class="work-record-sheet__yield-input"
                [class.work-record-sheet__yield-input--emphasized]="control.harvestContext"
                [(ngModel)]="control.form.amount_unit"
              />
            </div>
          </div>

          @if (amountDiff(); as diff) {
            <p
              class="work-record-sheet__amount-diff"
              [class.work-record-sheet__amount-diff--over]="diff.diff != null && diff.diff > 0"
              [class.work-record-sheet__amount-diff--under]="diff.diff != null && diff.diff < 0"
            >
              {{ amountDiffLabel(diff) }}
            </p>
          }

          @if (control.scheduleCategory === 'fertilizer') {
            <div class="form-card__field" data-testid="fertilize-master-picker">
              <label for="wr-fertilize">{{
                'plans.work.sheet.fertilizer.master_label' | translate
              }}</label>
              @if (control.loadingFertilizeOptions) {
                <p class="work-record-sheet__hint">{{ 'common.loading' | translate }}</p>
              } @else if (control.fertilizeOptions.length === 0) {
                <p class="work-record-sheet__hint">{{
                  'plans.work.sheet.fertilizer.master_empty' | translate
                }}</p>
                <a routerLink="/fertilizes/new" class="work-record-sheet__master-link">{{
                  'plans.work.sheet.fertilizer.master_add_link' | translate
                }}</a>
              } @else {
                <select id="wr-fertilize" name="fertilize_id" [(ngModel)]="control.form.fertilize_id">
                  <option [ngValue]="null">{{
                    'plans.work.sheet.fertilizer.master_placeholder' | translate
                  }}</option>
                  @for (option of control.fertilizeOptions; track option.id) {
                    <option [ngValue]="option.id">{{ option.name }}</option>
                  }
                </select>
              }
            </div>
          }

          @if (control.scheduleCategory === 'pest_control') {
            <div class="form-card__field" data-testid="pesticide-master-picker">
              <label for="wr-pesticide">{{
                'plans.work.sheet.pest_control.master_label' | translate
              }}</label>
              @if (control.cropId == null) {
                <p class="work-record-sheet__hint">{{
                  'plans.work.sheet.pest_control.master_crop_required' | translate
                }}</p>
              } @else if (control.loadingPesticideOptions) {
                <p class="work-record-sheet__hint">{{ 'common.loading' | translate }}</p>
              } @else if (control.pesticideOptions.length === 0) {
                <p class="work-record-sheet__hint">{{
                  'plans.work.sheet.pest_control.master_empty' | translate
                }}</p>
                <a routerLink="/pesticides/new" class="work-record-sheet__master-link">{{
                  'plans.work.sheet.pest_control.master_add_link' | translate
                }}</a>
              } @else {
                <select id="wr-pesticide" name="pesticide_id" [(ngModel)]="control.form.pesticide_id">
                  <option [ngValue]="null">{{
                    'plans.work.sheet.pest_control.master_placeholder' | translate
                  }}</option>
                  @for (option of control.pesticideOptions; track option.id) {
                    <option [ngValue]="option.id">{{ option.name }}</option>
                  }
                </select>
              }
            </div>
          }

          <div class="form-card__field">
            <label for="wr-time">{{ 'plans.work.sheet.time_spent' | translate }}</label>
            <input
              id="wr-time"
              type="number"
              name="time_spent_minutes"
              min="0"
              [(ngModel)]="control.form.time_spent_minutes"
            />
          </div>

          <div class="form-card__field">
            <label for="wr-notes">{{ 'plans.work.sheet.notes' | translate }}</label>
            <textarea id="wr-notes" name="notes" rows="3" [(ngModel)]="control.form.notes"></textarea>
          </div>
        }

        @if (showClimatePreview()) {
          <div class="work-record-sheet__climate-preview" data-testid="climate-preview">
            <span class="form-card__label">{{ 'plans.work.sheet.climate_preview.label' | translate }}</span>
            @if (control.climatePreview.loading) {
              <p class="work-record-sheet__hint">{{ 'plans.work.sheet.climate_preview.loading' | translate }}</p>
            } @else if (control.climatePreview.gddAtActual != null || control.climatePreview.weatherDate) {
              <p class="work-record-sheet__climate-preview-row">
                @if (control.climatePreview.gddAtActual != null) {
                  <span>
                    {{
                      'plans.work.sheet.climate_preview.gdd'
                        | translate: { value: control.climatePreview.gddAtActual }
                    }}
                  </span>
                }
                @if (
                  control.climatePreview.plannedGdd != null && control.climatePreview.gddAtActual != null
                ) {
                  <span>
                    {{
                      'plans.work.sheet.climate_preview.planned_gdd'
                        | translate: { value: control.climatePreview.plannedGdd }
                    }}
                  </span>
                  <span
                    class="work-record-sheet__gdd-diff"
                    [class.work-record-sheet__gdd-diff--over]="
                      control.climatePreview.gddDelta != null && control.climatePreview.gddDelta > 0
                    "
                    [class.work-record-sheet__gdd-diff--under]="
                      control.climatePreview.gddDelta != null && control.climatePreview.gddDelta < 0
                    "
                  >
                    {{
                      'plans.work.sheet.climate_preview.gdd_delta'
                        | translate: { value: climatePreviewGddDeltaLabel() }
                    }}
                  </span>
                }
                @if (control.climatePreview.weatherDate) {
                  <span>
                    {{
                      'plans.work.sheet.climate_preview.weather'
                        | translate
                          : {
                              max: control.climatePreview.temperatureMax,
                              min: control.climatePreview.temperatureMin,
                              mean: control.climatePreview.temperatureMean
                            }
                    }}
                  </span>
                }
              </p>
            } @else {
              <p class="work-record-sheet__hint">{{ 'plans.work.sheet.climate_preview.unavailable' | translate }}</p>
            }
          </div>
        }

        <div class="form-card__field work-record-sheet__photos">
          <span class="form-card__label" id="wr-photos-label">{{
            'plans.work.sheet.photos.label' | translate
          }}</span>
          @if (hasVisiblePhotos()) {
            <div class="work-record-sheet__photo-grid" role="list" aria-labelledby="wr-photos-label">
              @for (photo of visibleExistingPhotos(); track photo.id) {
                <div class="work-record-sheet__photo-thumb" role="listitem">
                  <img
                    [src]="photo.url"
                    alt=""
                    loading="lazy"
                    decoding="async"
                    [attr.width]="thumbWidthPx"
                    [attr.height]="thumbHeightPx"
                  />
                  <button
                    type="button"
                    class="work-record-sheet__photo-remove"
                    [attr.aria-label]="'plans.work.sheet.photos.remove' | translate"
                    (click)="removeExistingPhoto(photo.id)"
                  >
                    ×
                  </button>
                </div>
              }
              @for (pending of control.pendingPhotos; track pending.clientId) {
                <div class="work-record-sheet__photo-thumb" role="listitem">
                  <img
                    [src]="pending.previewUrl"
                    alt=""
                    loading="lazy"
                    decoding="async"
                    [attr.width]="thumbWidthPx"
                    [attr.height]="thumbHeightPx"
                  />
                  <button
                    type="button"
                    class="work-record-sheet__photo-remove"
                    [attr.aria-label]="'plans.work.sheet.photos.remove' | translate"
                    (click)="removePendingPhoto(pending.clientId)"
                  >
                    ×
                  </button>
                </div>
              }
            </div>
          }
          @if (canAddPhotos()) {
            <label class="work-record-sheet__photo-add">
              <input
                type="file"
                [accept]="photoAccept"
                capture="environment"
                (change)="onPhotosSelected($event)"
              />
              {{ 'plans.work.sheet.photos.add' | translate }}
            </label>
          }
          @if (control.photoError) {
            <p class="form-card__error">{{ control.photoError | translate }}</p>
          }
        </div>

        <div class="form-card__actions">
          @if (control.mode === 'edit') {
            <button
              type="button"
              class="btn-danger"
              [disabled]="control.submitting"
              (click)="confirmDelete()"
            >{{ 'plans.work_records.sheet.delete' | translate }}</button>
          }
          <button type="button" class="btn-secondary" (click)="close()">{{ 'common.cancel' | translate }}</button>
          <button
            type="submit"
            class="btn-primary"
            [disabled]="control.submitting || !canSubmit(recordForm)"
          >
            @if (control.mode === 'edit') {
              {{ 'plans.work_records.sheet.save' | translate }}
            } @else {
              {{ 'plans.work.sheet.submit' | translate }}
            }
          </button>
        </div>
      </form>
    </dialog>
  `,
  styleUrls: ['./work-record-sheet.component.css']
})
export class WorkRecordSheetComponent implements WorkRecordSheetView, OnInit {
  @Input({ required: true }) planId!: number;
  @Output() saved = new EventEmitter<WorkRecordSheetSavedEvent>();
  @Output() deleted = new EventEmitter<void>();

  @ViewChild('sheetDialog') sheetDialogRef!: ElementRef<HTMLDialogElement>;

  private readonly saveUseCase = inject(SaveWorkRecordSheetUseCase);
  private readonly deleteUseCase = inject(DeleteWorkRecordUseCase);
  private readonly loadTaskListUseCase = inject(LoadAgriculturalTaskListUseCase);
  private readonly loadFertilizeListUseCase = inject(LoadFertilizeListUseCase);
  private readonly loadCropPesticideListUseCase = inject(LoadCropPesticideListUseCase);
  private readonly previewClimateUseCase = inject(PreviewWorkRecordClimateUseCase);
  private readonly presenter = inject(WorkRecordSheetPresenter);
  readonly isAmountTrackedScheduleCategory = isAmountTrackedScheduleCategory;
  readonly photoAccept = WORK_RECORD_PHOTO_ACCEPT;
  readonly thumbWidthPx = WORK_RECORD_PHOTO_THUMB_WIDTH_PX_SHEET;
  readonly thumbHeightPx = WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_SHEET;

  private readonly apiBaseUrl = getApiBaseUrl();
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly undoToast = inject(UndoToastService);

  private _control: WorkRecordSheetViewState = initialControl;
  get control(): WorkRecordSheetViewState {
    return this._control;
  }
  set control(value: WorkRecordSheetViewState) {
    this._control = applyWorkRecordSheetViewEffects(value, {
      flash: this.flashMessage,
      toast: this.undoToast
    });
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.presenter.onSavedCallback = (event) => this.saved.emit(event);
    this.presenter.onDeletedCallback = () => this.deleted.emit();
  }

  openFromItem(
    row: WorkDayListRowDto,
    options?: { fieldErrors?: Record<string, string[]>; cropId?: number | null }
  ): void {
    const { item, fieldName, cropName } = row;
    const scheduleCategory = resolveScheduleCategory(item.category);
    const harvestContext = isHarvestTaskItem(item);
    const plannedAmount = item.amount ?? '';
    const plannedAmountUnit = item.amount_unit ?? '';
    const cropId = options?.cropId ?? null;
    this.control = {
      ...initialControl,
      mode: 'create-from-item',
      showDetails: isAmountTrackedScheduleCategory(scheduleCategory) || harvestContext,
      scheduleCategory,
      cropId,
      harvestContext,
      plannedAmount,
      plannedAmountUnit,
      fieldErrors: options?.fieldErrors ?? {},
      form: {
        name: item.name,
        actual_date: localTodayIso(),
        amount: plannedAmount,
        amount_unit: plannedAmountUnit,
        time_spent_minutes: '',
        notes: '',
        field_cultivation_id: item.field_cultivation_id,
        fieldName,
        cropName,
        task_schedule_item_id: item.item_id,
        work_record_id: null,
        agricultural_task_id: item.agricultural_task_id ?? null,
        fertilize_id: null,
        pesticide_id: null
      },
      fieldOptions: [],
      saveToastContext: {
        planId: this.planId,
        fieldCultivationId: item.field_cultivation_id,
        taskScheduleItemId: item.item_id,
        gddTrigger: item.gdd_trigger ?? item.details?.gdd?.trigger ?? null
      }
    };
    this.sheetDialogRef?.nativeElement?.showModal();
    this.refreshClimatePreview();
    this.loadMasterOptions(scheduleCategory, cropId);
  }

  openAdHoc(fieldOptions: FieldSchedule[]): void {
    this.control = {
      ...initialControl,
      mode: 'create-adhoc',
      form: emptyForm(),
      fieldOptions,
      loadingTaskChips: true
    };
    this.sheetDialogRef?.nativeElement?.showModal();
    this.loadTaskListUseCase.execute();
  }

  openEdit(
    record: WorkRecord,
    fieldName = '',
    cropName = '',
    options?: { cropId?: number | null }
  ): void {
    const scheduleCategory = scheduleCategoryFromTaskType(record.task_type);
    const cropId = options?.cropId ?? null;
    this.control = {
      ...initialControl,
      mode: 'edit',
      showDetails: true,
      scheduleCategory,
      cropId,
      harvestContext: isHarvestWorkRecord(record),
      plannedAmount: '',
      plannedAmountUnit: '',
      existingPhotos: (record.photos ?? []).map((photo) => ({
        id: photo.id,
        url: this.photoUrl(photo.url),
        markedForDelete: false
      })),
      form: {
        name: record.name,
        actual_date: record.actual_date,
        amount: record.amount ?? '',
        amount_unit: record.amount_unit ?? '',
        time_spent_minutes: record.time_spent_minutes != null ? String(record.time_spent_minutes) : '',
        notes: record.notes ?? '',
        field_cultivation_id: record.field_cultivation_id,
        fieldName,
        cropName,
        task_schedule_item_id: record.task_schedule_item_id,
        work_record_id: record.id,
        agricultural_task_id: record.agricultural_task_id,
        fertilize_id: record.fertilize_id ?? null,
        pesticide_id: record.pesticide_id ?? null,
        updated_at: record.updated_at
      },
      fieldOptions: []
    };
    this.sheetDialogRef?.nativeElement?.showModal();
    this.refreshClimatePreview();
    this.loadMasterOptions(scheduleCategory, cropId);
  }

  selectTaskChip(chip: WorkRecordSheetTaskChip): void {
    const scheduleCategory = scheduleCategoryFromTaskType(chip.task_type);
    this.control = {
      ...this.control,
      selectedTaskId: chip.id,
      scheduleCategory,
      form: {
        ...this.control.form,
        name: chip.name,
        agricultural_task_id: chip.id,
        fertilize_id: null,
        pesticide_id: null
      }
    };
    this.loadMasterOptions(scheduleCategory, this.control.cropId);
  }

  selectOtherTask(): void {
    this.control = {
      ...this.control,
      selectedTaskId: 'other',
      form: {
        ...this.control.form,
        name: '',
        agricultural_task_id: null
      }
    };
  }

  toggleDetails(): void {
    this.control = { ...this.control, showDetails: !this.control.showDetails };
    if (this.control.showDetails) {
      this.refreshClimatePreview();
    }
  }

  onClimateInputsChanged(): void {
    this.refreshClimatePreview();
  }

  onFieldCultivationChanged(fieldCultivationId: number | null): void {
    const cropId = resolveCropIdForFieldCultivation(this.control.fieldOptions, fieldCultivationId);
    this.control = {
      ...this.control,
      cropId,
      form: {
        ...this.control.form,
        field_cultivation_id: fieldCultivationId,
        pesticide_id: null
      },
      pesticideOptions: []
    };
    this.onClimateInputsChanged();
    if (this.control.scheduleCategory === 'pest_control') {
      this.loadPesticideOptions(cropId);
    }
  }

  private loadMasterOptions(
    scheduleCategory: WorkRecordScheduleCategory,
    cropId: number | null
  ): void {
    if (scheduleCategory === 'fertilizer') {
      this.loadFertilizeOptions();
    }
    if (scheduleCategory === 'pest_control') {
      this.loadPesticideOptions(cropId);
    }
  }

  private loadFertilizeOptions(): void {
    this.control = {
      ...this.control,
      loadingFertilizeOptions: true,
      fertilizeOptions: []
    };
    this.loadFertilizeListUseCase.execute();
  }

  private loadPesticideOptions(cropId: number | null): void {
    if (cropId == null) {
      this.control = {
        ...this.control,
        loadingPesticideOptions: false,
        pesticideOptions: []
      };
      return;
    }
    this.control = {
      ...this.control,
      loadingPesticideOptions: true,
      pesticideOptions: []
    };
    this.loadCropPesticideListUseCase.execute({ cropId });
  }

  onAmountChanged(): void {
    this.cdr.markForCheck();
  }

  amountDiff(): WorkRecordAmountDiff | null {
    if (!isAmountTrackedScheduleCategory(this.control.scheduleCategory)) {
      return null;
    }
    return computeWorkRecordAmountDiff(
      this.control.plannedAmount,
      this.control.form.amount,
      this.control.form.amount_unit || this.control.plannedAmountUnit
    );
  }

  amountDiffLabel(diff: WorkRecordAmountDiff): string {
    if (diff.diff == null) {
      return '';
    }
    const sign = diff.diff > 0 ? '+' : '';
    return `${sign}${diff.diff}${diff.unit ? ` ${diff.unit}` : ''}`;
  }

  showClimatePreview(): boolean {
    return this.control.form.field_cultivation_id != null && Boolean(this.control.form.actual_date.trim());
  }

  climatePreviewGddDeltaLabel(): string {
    const delta = this.control.climatePreview.gddDelta;
    if (delta == null) {
      return '';
    }
    return formatVarianceGddDelta(delta);
  }

  private refreshClimatePreview(): void {
    if (!this.showClimatePreview()) {
      this.control = {
        ...this.control,
        climatePreview: emptyClimatePreview()
      };
      return;
    }
    this.previewClimateUseCase.execute({
      fieldCultivationId: this.control.form.field_cultivation_id,
      actualDate: this.control.form.actual_date,
      gddTrigger: this.control.saveToastContext?.gddTrigger ?? null
    });
  }

  canSubmit(recordForm: NgForm): boolean {
    if (!recordForm.controls['actual_date']?.valid) {
      return false;
    }
    if (this.control.mode === 'edit') {
      return recordForm.valid === true;
    }
    if (this.control.mode === 'create-from-item') {
      return Boolean(this.control.form.name.trim());
    }
    if (this.control.selectedTaskId === 'other') {
      return Boolean(this.control.form.name.trim());
    }
    return this.control.selectedTaskId != null;
  }

  close(): void {
    this.sheetDialogRef?.nativeElement?.close();
  }

  onDialogClose(): void {
    this.revokePendingPhotoUrls(this.control.pendingPhotos);
    this.control = {
      ...initialControl,
      form: emptyForm()
    };
  }

  visibleExistingPhotos(): WorkRecordSheetExistingPhoto[] {
    return this.control.existingPhotos.filter((photo) => !photo.markedForDelete);
  }

  hasVisiblePhotos(): boolean {
    return this.visibleExistingPhotos().length > 0 || this.control.pendingPhotos.length > 0;
  }

  canAddPhotos(): boolean {
    return this.photoSlotCount() < MAX_WORK_RECORD_PHOTOS;
  }

  onPhotosSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const files = input.files ? Array.from(input.files) : [];
    input.value = '';
    if (files.length === 0) {
      return;
    }

    const slotsLeft = MAX_WORK_RECORD_PHOTOS - this.photoSlotCount();
    if (slotsLeft <= 0) {
      this.control = {
        ...this.control,
        photoError: 'plans.work.sheet.photos.errors.limit_reached'
      };
      return;
    }

    const accepted = files.slice(0, slotsLeft).filter((file) => this.isAllowedPhoto(file));
    if (accepted.length === 0) {
      this.control = {
        ...this.control,
        photoError: 'plans.work.sheet.photos.errors.invalid_type'
      };
      return;
    }

    const pendingPhotos = [
      ...this.control.pendingPhotos,
      ...accepted.map((file) => ({
        clientId: crypto.randomUUID(),
        previewUrl: URL.createObjectURL(file),
        file
      }))
    ];
    this.control = {
      ...this.control,
      pendingPhotos,
      photoError: null
    };
  }

  removePendingPhoto(clientId: string): void {
    const target = this.control.pendingPhotos.find((photo) => photo.clientId === clientId);
    if (target) {
      URL.revokeObjectURL(target.previewUrl);
    }
    this.control = {
      ...this.control,
      pendingPhotos: this.control.pendingPhotos.filter((photo) => photo.clientId !== clientId),
      photoError: null
    };
  }

  removeExistingPhoto(photoId: number): void {
    this.control = {
      ...this.control,
      existingPhotos: this.control.existingPhotos.map((photo) =>
        photo.id === photoId ? { ...photo, markedForDelete: true } : photo
      ),
      photoError: null
    };
  }

  private photoSlotCount(): number {
    return this.visibleExistingPhotos().length + this.control.pendingPhotos.length;
  }

  private isAllowedPhoto(file: File): boolean {
    return WORK_RECORD_PHOTO_ACCEPT.split(',').includes(file.type);
  }

  private photoUrl(path: string): string {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return `${this.apiBaseUrl}${path}`;
  }

  private revokePendingPhotoUrls(photos: WorkRecordSheetPendingPhoto[]): void {
    for (const photo of photos) {
      URL.revokeObjectURL(photo.previewUrl);
    }
  }

  fieldError(field: string): string | null {
    const errors = this.control.fieldErrors[field];
    return errors?.[0] ?? null;
  }

  submit(): void {
    const { form, mode } = this.control;
    this.control = { ...this.control, submitting: true, fieldErrors: {}, error: null, photoError: null };

    const formInput = {
      task_schedule_item_id: form.task_schedule_item_id,
      name: form.name,
      actual_date: form.actual_date,
      amount: form.amount,
      amount_unit: form.amount_unit,
      time_spent_minutes: form.time_spent_minutes,
      notes: form.notes,
      field_cultivation_id: form.field_cultivation_id,
      agricultural_task_id: form.agricultural_task_id,
      fertilize_id: form.fertilize_id,
      pesticide_id: form.pesticide_id,
      updated_at: form.updated_at
    };

    const photoIdsToDelete = this.control.existingPhotos
      .filter((photo) => photo.markedForDelete)
      .map((photo) => photo.id);
    const pendingPhotoFiles = this.control.pendingPhotos.map((photo) => photo.file);

    if (mode === 'edit' && form.work_record_id != null) {
      this.saveUseCase.execute({
        planId: this.planId,
        mode,
        workRecordId: form.work_record_id,
        updateBody: mapFormToUpdateRequest(formInput),
        pendingPhotoFiles,
        photoIdsToDelete
      });
      return;
    }

    this.saveUseCase.execute({
      planId: this.planId,
      mode,
      createBody: mapFormToCreateRequest(formInput),
      pendingPhotoFiles,
      photoIdsToDelete
    });
  }

  confirmDelete(): void {
    const id = this.control.form.work_record_id;
    if (id == null) return;
    this.control = { ...this.control, submitting: true };
    this.deleteUseCase.execute({ planId: this.planId, workRecordId: id });
  }
}

function resolveScheduleCategory(category: string): WorkRecordScheduleCategory {
  if (category === 'fertilizer' || category === 'pest_control') {
    return category;
  }
  if (category === 'general') {
    return 'general';
  }
  return null;
}
