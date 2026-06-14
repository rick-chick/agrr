import { FieldSchedule } from '../../models/plans/task-schedule';

export type WorkRecordSheetMode = 'create-from-item' | 'create-adhoc' | 'edit';

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
}

export interface WorkRecordSheetViewState {
  mode: WorkRecordSheetMode;
  submitting: boolean;
  error: string | null;
  fieldErrors: Record<string, string[]>;
  form: WorkRecordSheetFormState;
  fieldOptions: FieldSchedule[];
}

export interface WorkRecordSheetView {
  control: WorkRecordSheetViewState;
  close(): void;
}
