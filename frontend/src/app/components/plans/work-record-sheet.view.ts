import { FieldSchedule } from '../../models/plans/task-schedule';
import { WorkRecord } from '../../models/plans/work-record';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';

export type WorkRecordSheetMode = 'create-from-item' | 'create-adhoc' | 'edit';

export interface WorkRecordSheetTaskChip {
  id: number;
  name: string;
  task_type: string | null;
}

export interface WorkRecordSheetSavedEvent {
  workRecord: WorkRecord;
  mode: WorkRecordSheetMode;
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
}

export interface WorkRecordSheetViewState {
  mode: WorkRecordSheetMode;
  submitting: boolean;
  error: string | null;
  fieldErrors: Record<string, string[]>;
  form: WorkRecordSheetFormState;
  fieldOptions: FieldSchedule[];
  showDetails: boolean;
  taskChips: WorkRecordSheetTaskChip[];
  loadingTaskChips: boolean;
  selectedTaskId: number | 'other' | null;
  pendingToastKey: string | null;
  pendingUndoToast: PendingUndoToastRequest | null;
  existingPhotos: WorkRecordSheetExistingPhoto[];
  pendingPhotos: WorkRecordSheetPendingPhoto[];
  photoError: string | null;
}

export interface WorkRecordSheetView {
  control: WorkRecordSheetViewState;
  close(): void;
}
