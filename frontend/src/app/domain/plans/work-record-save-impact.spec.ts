import { describe, expect, it } from 'vitest';
import { WorkRecord } from '../../models/plans/work-record';
import {
  buildWorkRecordSaveImpactPanel,
  shouldShowWorkRecordSaveImpact,
  type WorkRecordSaveImpactRequest
} from './work-record-save-impact';

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

function request(
  overrides: Partial<WorkRecordSaveImpactRequest> = {}
): WorkRecordSaveImpactRequest {
  return {
    workRecord: record({ id: 1, actual_date: '2026-06-13', name: 'Weeding' }),
    mode: 'create-from-item',
    planId: 7,
    gddTrigger: 100,
    ...overrides
  };
}

describe('shouldShowWorkRecordSaveImpact', () => {
  it('returns true for schedule-linked create with variance', () => {
    expect(shouldShowWorkRecordSaveImpact(request())).toBe(true);
  });

  it('returns false for edit mode', () => {
    expect(shouldShowWorkRecordSaveImpact(request({ mode: 'edit' }))).toBe(false);
  });

  it('returns false for ad-hoc create', () => {
    expect(
      shouldShowWorkRecordSaveImpact(
        request({
          mode: 'create-adhoc',
          workRecord: record({
            id: 1,
            actual_date: '2026-06-13',
            name: 'Weeding',
            task_schedule_item_id: null,
            task_schedule_item: null
          })
        })
      )
    ).toBe(false);
  });
});

describe('buildWorkRecordSaveImpactPanel', () => {
  it('combines task variance with refreshed plan summary stats', () => {
    const panel = buildWorkRecordSaveImpactPanel(request(), {
      plan_id: 7,
      unrecorded_count: 4,
      categories: [
        {
          category: 'general',
          average_delta_days: 1.5,
          item_count: 3,
          recorded_count: 2
        }
      ],
      top_variance_items: []
    });

    expect(panel).toEqual({
      planId: 7,
      taskName: 'Weeding',
      deltaDays: '+3',
      gddDelta: '+30.5',
      unrecordedCount: 4,
      averageDeltaDays: '+1.5'
    });
  });

  it('returns null when impact preview does not apply', () => {
    expect(
      buildWorkRecordSaveImpactPanel(request({ mode: 'edit' }), {
        plan_id: 7,
        unrecorded_count: 0,
        categories: [],
        top_variance_items: []
      })
    ).toBeNull();
  });
});
