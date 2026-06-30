import {
  WorkRecordCreateRequest,
  WorkRecordUpdateRequest
} from '../../models/plans/work-record';

export interface WorkRecordFormInput {
  task_schedule_item_id: number | null;
  name: string;
  actual_date: string;
  amount: string;
  amount_unit: string;
  time_spent_minutes: string;
  notes: string;
  field_cultivation_id: number | null;
  agricultural_task_id?: number | null;
}

export function mapFormToCreateRequest(form: WorkRecordFormInput): WorkRecordCreateRequest {
  const body: WorkRecordCreateRequest = { actual_date: form.actual_date };

  if (form.task_schedule_item_id != null) {
    body.task_schedule_item_id = form.task_schedule_item_id;
    if (form.name) body.name = form.name;
    if (form.amount) body.amount = form.amount;
    if (form.amount_unit) body.amount_unit = form.amount_unit;
    if (form.notes) body.notes = form.notes;
    if (form.time_spent_minutes) body.time_spent_minutes = Number(form.time_spent_minutes);
    return body;
  }

  body.name = form.name;
  if (form.agricultural_task_id != null) body.agricultural_task_id = form.agricultural_task_id;
  if (form.field_cultivation_id != null) body.field_cultivation_id = form.field_cultivation_id;
  if (form.amount) body.amount = form.amount;
  if (form.amount_unit) body.amount_unit = form.amount_unit;
  if (form.notes) body.notes = form.notes;
  if (form.time_spent_minutes) body.time_spent_minutes = Number(form.time_spent_minutes);
  return body;
}

export function mapFormToUpdateRequest(form: WorkRecordFormInput): WorkRecordUpdateRequest {
  return {
    name: form.name,
    actual_date: form.actual_date,
    amount: form.amount || undefined,
    amount_unit: form.amount_unit || undefined,
    time_spent_minutes: form.time_spent_minutes ? Number(form.time_spent_minutes) : undefined,
    notes: form.notes || undefined
  };
}
