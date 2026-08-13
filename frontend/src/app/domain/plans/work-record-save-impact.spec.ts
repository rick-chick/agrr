import { describe, expect, it } from 'vitest';
import { WorkRecord } from '../../models/plans/work-record';
import { buildWorkRecordSaveImpact } from './work-record-save-impact';

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

const planStats = {
  completedCount: 3,
  averageDeltaDays: 2.5,
  unrecordedCount: 4
};

describe('buildWorkRecordSaveImpact', () => {
  it('returns null for edit mode', () => {
    expect(
      buildWorkRecordSaveImpact(
        record({ id: 1, actual_date: '2026-06-13', name: 'Weeding' }),
        'edit',
        planStats,
        { planId: 7, fieldCultivationId: 10, taskScheduleItemId: 5, gddTrigger: 100 }
      )
    ).toBeNull();
  });

  it('includes task variance and plan stats for schedule-linked create', () => {
    expect(
      buildWorkRecordSaveImpact(
        record({ id: 1, actual_date: '2026-06-13', name: 'Weeding' }),
        'create-from-item',
        planStats,
        { planId: 7, fieldCultivationId: 10, taskScheduleItemId: 5, gddTrigger: 100 }
      )
    ).toEqual({
      taskName: 'Weeding',
      deltaDays: '+3',
      gddDelta: '+30.5',
      planStats,
      workbenchFieldCultivationId: null
    });
  });

  it('includes workbench deep link when the saved task exceeds variance threshold', () => {
    expect(
      buildWorkRecordSaveImpact(
        record({ id: 1, actual_date: '2026-06-13', name: 'Weeding' }),
        'create-from-item',
        planStats,
        { planId: 7, fieldCultivationId: 10, taskScheduleItemId: 5, gddTrigger: 100 },
        [
          {
            item_id: 5,
            field_cultivation_id: 10,
            category: 'general',
            name: 'Weeding',
            scheduled_date: '2026-06-10',
            actual_date: '2026-06-13',
            delta_days: 3,
            gdd_trigger: 100,
            gdd_at_actual: 130.5,
            gdd_delta: 30.5,
            exceedance_kind: 'both'
          }
        ]
      )
    ).toMatchObject({
      workbenchFieldCultivationId: 10
    });
  });

  it('returns plan stats without task variance for ad-hoc create', () => {
    expect(
      buildWorkRecordSaveImpact(
        record({
          id: 1,
          actual_date: '2026-06-13',
          name: 'Extra work',
          task_schedule_item_id: null,
          task_schedule_item: null
        }),
        'create-adhoc',
        planStats,
        null
      )
    ).toEqual({
      taskName: 'Extra work',
      deltaDays: null,
      gddDelta: null,
      planStats,
      workbenchFieldCultivationId: null
    });
  });
});
