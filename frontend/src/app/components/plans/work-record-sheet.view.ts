import { FieldSchedule } from '../../models/plans/task-schedule';
import { WorkRecord } from '../../models/plans/work-record';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';
import { PendingToastRequest } from '../../core/view-effects/pending-toast-view.effects';
import { WorkRecordSaveToastContext } from '../../domain/plans/work-record-save-toast';
import { WorkRecordScheduleCategory } from '../../domain/work-schedule/work-record-sheet-schedule';

export type WorkRecordSheetMode = 'create-from-item' | 'create-adhoc' | 'edit';
export type { WorkRecordScheduleCategory };

export interface WorkRecordClimatePreviewState {
  gddAtActual: number | null;
  weatherDate: string | null;
  temperatureMax: number | null;
  temperatureMin: number | null;
  temperatureMean: number | null;
  plannedGdd: number | null;
  gddDelta: number | null;
  loading: boolean;
}

export interface WorkRecordSheetTaskChip {
  id: number;
  name: string;
  task_type: string | null;
}

export interface WorkRecordSheetSavedEvent {
  workRecord: WorkRecord;
  mode: WorkRecordSheetMode;
  saveToastContext?: WorkRecordSaveToastContext | null;
}

export interface WorkRecordSheetExistingPhoto {
  id: number;
  url: string;
  markedForDelete: boolean;
}

export interface WorkRecordSheetPendingPhoto {
  clientId: string;
  previewUrl: string;
  file: File;
}

export interface WorkRecordSheetMasterOption {
  id: number;
  name: string;
}

export interface WorkRecordSheetFormState {
  name: string;
  actual_date: string;
  amount: string;
  amount_unit: string;
  time_spent_minutes: string;
  notes: string;
  field_cultivation_id: number | null;
  fieldName: string;
  cropName: string;
  task_schedule_item_id: number | null;
  work_record_id: number | null;
  agricultural_task_id: number | null;
  fertilize_id: number | null;
  pesticide_id: number | null;
  updated_at?: string;
}

export interface WorkRecordSheetViewState {
  mode: WorkRecordSheetMode;
  submitting: boolean;
  error: string | null;
  fieldErrors: Record<string, string[]>;
  form: WorkRecordSheetFormState;
  fieldOptions: FieldSchedule[];
  scheduleCategory: WorkRecordScheduleCategory;
  cropId: number | null;
  fertilizeOptions: WorkRecordSheetMasterOption[];
  pesticideOptions: WorkRecordSheetMasterOption[];
  loadingFertilizeOptions: boolean;
  loadingPesticideOptions: boolean;
  /** Harvest milestone v1: emphasize yield fields in the sheet. */
  harvestContext: boolean;
  plannedAmount: string;
  plannedAmountUnit: string;
  climatePreview: WorkRecordClimatePreviewState;
  showDetails: boolean;
  taskChips: WorkRecordSheetTaskChip[];
  loadingTaskChips: boolean;
  selectedTaskId: number | 'other' | null;
  pendingToast: PendingToastRequest | null;
  saveToastContext: WorkRecordSaveToastContext | null;
  pendingUndoToast: PendingUndoToastRequest | null;
  existingPhotos: WorkRecordSheetExistingPhoto[];
  pendingPhotos: WorkRecordSheetPendingPhoto[];
  photoError: string | null;
}

export interface WorkRecordSheetView {
  control: WorkRecordSheetViewState;
  close(): void;
}
