import { describe, it, expect } from 'vitest';
import { mapFormToCreateRequest, mapFormToUpdateRequest } from './work-record-form.mapper';

const baseForm = {
  name: '追肥',
  actual_date: '2026-06-12',
  amount: '1.5',
  amount_unit: 'kg',
  time_spent_minutes: '30',
  notes: 'memo',
  field_cultivation_id: 10,
  task_schedule_item_id: null as number | null
};

describe('work-record-form.mapper', () => {
  it('maps scheduled item create with overrides only when set', () => {
    const body = mapFormToCreateRequest({
      ...baseForm,
      task_schedule_item_id: 123,
      name: '',
      amount: '',
      notes: ''
    });

    expect(body).toEqual({
      task_schedule_item_id: 123,
      actual_date: '2026-06-12',
      amount_unit: 'kg',
      time_spent_minutes: 30
    });
  });

  it('maps ad hoc create with name required fields', () => {
    const body = mapFormToCreateRequest({
      ...baseForm,
      task_schedule_item_id: null,
      name: '緊急防除'
    });

    expect(body.name).toBe('緊急防除');
    expect(body.field_cultivation_id).toBe(10);
    expect(body.task_schedule_item_id).toBeUndefined();
  });

  it('maps ad hoc create with agricultural_task_id from chip selection', () => {
    const body = mapFormToCreateRequest({
      ...baseForm,
      task_schedule_item_id: null,
      name: '除草',
      agricultural_task_id: 5
    });

    expect(body.agricultural_task_id).toBe(5);
    expect(body.name).toBe('除草');
  });

  it('maps update request from form', () => {
    const body = mapFormToUpdateRequest(baseForm);
    expect(body).toEqual({
      name: '追肥',
      actual_date: '2026-06-12',
      amount: '1.5',
      amount_unit: 'kg',
      time_spent_minutes: 30,
      notes: 'memo'
    });
  });
});
