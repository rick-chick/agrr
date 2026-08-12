import { describe, expect, it } from 'vitest';
import { WorkRecord } from '../../models/plans/work-record';
import { buildWorkRecordSaveToast } from './work-record-save-toast';

function record(
  overrides: Partial<WorkRecord> & Pick<WorkRecord, 'id' | 'actual_date' | 'name'>
): WorkRecord {
  return {
    cultivation_plan_id: 1,
    field_cultivation_id: 10,
    task_schedule_item_id: 5,
    agricultural_task_id: null,
    task_type: null,
    amount: null,
    amount_unit: null,
    time_spent_minutes: null,
    notes: null,
    created_at: '2026-06-01',
    updated_at: '2026-06-01',
    task_schedule_item: { id: 5, name: 'Weeding', scheduled_date: '2026-06-10' },
    gdd_at_actual: 130.5,
    ...overrides
  };
}

describe('buildWorkRecordSaveToast', () => {
  it('returns variance toast with navigation for schedule-linked create', () => {
    const toast = buildWorkRecordSaveToast(
      record({ id: 1, actual_date: '2026-06-13', name: 'Weeding' }),
      'create-from-item',
      {
        planId: 7,
        fieldCultivationId: 10,
        taskScheduleItemId: 5,
        gddTrigger: 100
      }
    );

    expect(toast).toEqual({
      textKey: 'plans.work.toast.record_saved_variance',
      textParams: {
        name: 'Weeding',
        deltaDays: '+3',
        gddDelta: '+30.5'
      },
      action: {
        labelKey: 'plans.work.toast.view_task_detail',
        routerLink: ['/plans', 7, 'task_schedule'],
        queryParams: {
          field_cultivation_id: 10,
          item_id: 5
        }
      }
    });
  });

  it('returns ad-hoc toast when record is not schedule-linked', () => {
    const toast = buildWorkRecordSaveToast(
      record({
        id: 1,
        actual_date: '2026-06-13',
        name: 'Weeding',
        task_schedule_item_id: null,
        task_schedule_item: null
      }),
      'create-adhoc',
      null
    );

    expect(toast.textKey).toBe('plans.work.toast.record_saved_adhoc');
    expect(toast.action).toBeUndefined();
  });
});
