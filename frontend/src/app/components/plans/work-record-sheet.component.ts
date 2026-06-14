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
import { FormsModule } from '@angular/forms';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { localTodayIso } from '../../core/local-today';
import { FieldSchedule } from '../../models/plans/task-schedule';
import { WorkRecord } from '../../models/plans/work-record';
import { WorkRecordSheetPresenter } from '../../adapters/plans/work-record-sheet.presenter';
import { CreateWorkRecordUseCase } from '../../usecase/plans/create-work-record.usecase';
import { DeleteWorkRecordUseCase } from '../../usecase/plans/delete-work-record.usecase';
import { UpdateWorkRecordUseCase } from '../../usecase/plans/update-work-record.usecase';
import { WORK_RECORD_SHEET_PROVIDERS } from '../../usecase/plans/work-record-sheet.providers';
import {
  mapFormToCreateRequest,
  mapFormToUpdateRequest
} from '../../usecase/plans/work-record-form.mapper';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import {
  WorkRecordSheetFormState,
  WorkRecordSheetView,
  WorkRecordSheetViewState
} from './work-record-sheet.view';

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
    work_record_id: null
  };
}

const initialControl: WorkRecordSheetViewState = {
  mode: 'create-adhoc',
  submitting: false,
  error: null,
  fieldErrors: {},
  form: emptyForm(),
  fieldOptions: []
};

@Component({
  selector: 'app-work-record-sheet',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
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

        <div class="form-card__field">
          <label for="wr-date">{{ 'plans.work.sheet.actual_date' | translate }}</label>
          <input id="wr-date" type="date" name="actual_date" [(ngModel)]="control.form.actual_date" required />
          @if (fieldError('actual_date')) {
            <p class="form-card__error">{{ fieldError('actual_date') | translate }}</p>
          }
        </div>

        <div class="form-card__field form-card__field--row">
          <div>
            <label for="wr-amount">{{ 'plans.work.sheet.amount' | translate }}</label>
            <input id="wr-amount" type="text" name="amount" [(ngModel)]="control.form.amount" />
          </div>
          <div>
            <label for="wr-unit">{{ 'plans.work.sheet.amount_unit' | translate }}</label>
            <input id="wr-unit" type="text" name="amount_unit" [(ngModel)]="control.form.amount_unit" />
          </div>
        </div>

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

        @if (control.mode === 'create-from-item') {
          <div class="form-card__field">
            <span class="form-card__label">{{ 'plans.work.sheet.field' | translate }}</span>
            <p>{{ control.form.fieldName }} {{ control.form.cropName }}</p>
          </div>
        } @else if (control.mode === 'create-adhoc') {
          <div class="form-card__field">
            <label for="wr-field">{{ 'plans.work.sheet.field_select' | translate }}</label>
            <select id="wr-field" name="field_cultivation_id" [(ngModel)]="control.form.field_cultivation_id">
              <option [ngValue]="null">{{ 'plans.work.sheet.field_optional' | translate }}</option>
              @for (field of control.fieldOptions; track field.field_cultivation_id) {
                <option [ngValue]="field.field_cultivation_id">
                  {{ field.name }} {{ field.crop_name }}
                </option>
              }
            </select>
          </div>
        } @else {
          <div class="form-card__field">
            <span class="form-card__label">{{ 'plans.work.sheet.field' | translate }}</span>
            <p>
              @if (control.form.fieldName) {
                {{ control.form.fieldName }} {{ control.form.cropName }}
              } @else {
                {{ 'plans.work_records.badge.adhoc' | translate }}
              }
            </p>
          </div>
        }

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
          <button type="submit" class="btn-primary" [disabled]="control.submitting || !recordForm.valid">
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
  @Output() saved = new EventEmitter<void>();
  @Output() deleted = new EventEmitter<void>();

  @ViewChild('sheetDialog') sheetDialogRef!: ElementRef<HTMLDialogElement>;

  private readonly createUseCase = inject(CreateWorkRecordUseCase);
  private readonly updateUseCase = inject(UpdateWorkRecordUseCase);
  private readonly deleteUseCase = inject(DeleteWorkRecordUseCase);
  private readonly presenter = inject(WorkRecordSheetPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

  private _control: WorkRecordSheetViewState = initialControl;
  get control(): WorkRecordSheetViewState {
    return this._control;
  }
  set control(value: WorkRecordSheetViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.presenter.onSavedCallback = () => this.saved.emit();
    this.presenter.onDeletedCallback = () => this.deleted.emit();
  }

  openFromItem(row: WorkDayListRowDto): void {
    const { item, fieldName, cropName } = row;
    this.control = {
      ...initialControl,
      mode: 'create-from-item',
      form: {
        name: item.name,
        actual_date: localTodayIso(),
        amount: item.amount ?? '',
        amount_unit: item.amount_unit ?? '',
        time_spent_minutes: '',
        notes: '',
        field_cultivation_id: item.field_cultivation_id,
        fieldName,
        cropName,
        task_schedule_item_id: item.item_id,
        work_record_id: null
      },
      fieldOptions: []
    };
    this.sheetDialogRef?.nativeElement?.showModal();
  }

  openAdHoc(fieldOptions: FieldSchedule[]): void {
    this.control = {
      ...initialControl,
      mode: 'create-adhoc',
      form: emptyForm(),
      fieldOptions
    };
    this.sheetDialogRef?.nativeElement?.showModal();
  }

  openEdit(record: WorkRecord, fieldName = '', cropName = ''): void {
    this.control = {
      ...initialControl,
      open: true,
      mode: 'edit',
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
        work_record_id: record.id
      },
      fieldOptions: []
    };
    this.sheetDialogRef?.nativeElement?.showModal();
  }

  close(): void {
    this.sheetDialogRef?.nativeElement?.close();
  }

  onDialogClose(): void {
    this.control = { ...this.control, submitting: false, fieldErrors: {}, error: null };
  }

  fieldError(field: string): string | null {
    const errors = this.control.fieldErrors[field];
    return errors?.[0] ?? null;
  }

  submit(): void {
    const { form, mode } = this.control;
    this.control = { ...this.control, submitting: true, fieldErrors: {}, error: null };

    const formInput = {
      task_schedule_item_id: form.task_schedule_item_id,
      name: form.name,
      actual_date: form.actual_date,
      amount: form.amount,
      amount_unit: form.amount_unit,
      time_spent_minutes: form.time_spent_minutes,
      notes: form.notes,
      field_cultivation_id: form.field_cultivation_id
    };

    if (mode === 'edit' && form.work_record_id != null) {
      this.updateUseCase.execute({
        planId: this.planId,
        workRecordId: form.work_record_id,
        body: mapFormToUpdateRequest(formInput)
      });
      return;
    }

    this.createUseCase.execute({
      planId: this.planId,
      body: mapFormToCreateRequest(formInput)
    });
  }

  confirmDelete(): void {
    const id = this.control.form.work_record_id;
    if (id == null) return;
    const message = this.translate.instant('plans.work_records.sheet.delete_confirm');
    if (!window.confirm(message)) {
      return;
    }
    this.control = { ...this.control, submitting: true };
    this.deleteUseCase.execute({ planId: this.planId, workRecordId: id });
  }
}
