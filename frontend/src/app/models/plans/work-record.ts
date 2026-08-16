import type { ClimateTemperaturePoint } from '../../domain/plans/field-cultivation-climate-data';
import { WorkRecordPhoto } from './work-record-photo';

export interface WorkRecordTaskScheduleItemRef {
  id: number;
  name: string;
  scheduled_date: string | null;
}

export interface WorkRecord {
  id: number;
  cultivation_plan_id: number;
  field_cultivation_id: number | null;
  task_schedule_item_id: number | null;
  agricultural_task_id: number | null;
  name: string;
  task_type: string | null;
  actual_date: string;
  amount: string | null;
  amount_unit: string | null;
  time_spent_minutes: number | null;
  notes: string | null;
  fertilize_id?: number | null;
  pesticide_id?: number | null;
  gdd_at_actual?: number | null;
  weather_snapshot?: ClimateTemperaturePoint | null;
  field_name?: string | null;
  crop_name?: string | null;
  created_at: string;
  updated_at: string;
  task_schedule_item: WorkRecordTaskScheduleItemRef | null;
  photos?: WorkRecordPhoto[];
}

export interface WorkRecordCreateRequest {
  task_schedule_item_id?: number;
  name?: string;
  task_type?: string;
  actual_date: string;
  amount?: string;
  amount_unit?: string;
  time_spent_minutes?: number;
  notes?: string;
  field_cultivation_id?: number;
  agricultural_task_id?: number;
  fertilize_id?: number | null;
  pesticide_id?: number | null;
}

export interface WorkRecordUpdateRequest {
  name?: string;
  actual_date?: string;
  amount?: string;
  amount_unit?: string;
  time_spent_minutes?: number;
  notes?: string;
  fertilize_id?: number | null;
  pesticide_id?: number | null;
}

export interface WorkRecordsListResponse {
  work_records: WorkRecord[];
}

export interface WorkRecordCreateResponse {
  work_record: WorkRecord;
}

export interface WorkRecordUpdateResponse {
  work_record: WorkRecord;
}
