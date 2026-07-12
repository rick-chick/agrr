import { describe, expect, it } from 'vitest';
import type { PlanTaskScheduleItem } from './plan-schedule-snapshot';
import { emptyPlanTaskScheduleItemDetails } from './plan-schedule-snapshot';
import { flattenCrossFarmSchedules } from './flatten-cross-farm-schedule';
import type { CrossFarmScheduleSource } from './cross-farm-schedule-row';

function mockTask(
  overrides: Partial<PlanTaskScheduleItem> & Pick<PlanTaskScheduleItem, 'item_id'>
): PlanTaskScheduleItem {
  return {
    name: 'Task',
    scheduled_date: '2026-06-10',
    status: 'planned',
    details: emptyPlanTaskScheduleItemDetails,
    ...overrides
  };
}

function mockSource(
  overrides: Partial<CrossFarmScheduleSource> & Pick<CrossFarmScheduleSource, 'farmId' | 'planId'>
): CrossFarmScheduleSource {
  return {
    farmName: 'Farm A',
    planName: 'Plan A',
    fields: [],
    ...overrides
  };
}

describe('flattenCrossFarmSchedules', () => {
  it('flattens scheduled tasks from multiple farms sorted by date', () => {
    const rows = flattenCrossFarmSchedules([
      mockSource({
        farmId: 1,
        planId: 10,
        fields: [
          {
            name: 'Field 1',
            crop_name: 'Tomato',
            field_cultivation_id: 101,
            schedules: {
              general: [mockTask({ item_id: 1, name: 'Late', scheduled_date: '2026-06-15' })],
              fertilizer: []
            }
          }
        ]
      }),
      mockSource({
        farmId: 2,
        farmName: 'Farm B',
        planId: 20,
        planName: 'Plan B',
        fields: [
          {
            name: 'Field 2',
            crop_name: 'Carrot',
            field_cultivation_id: 201,
            schedules: {
              general: [mockTask({ item_id: 2, name: 'Early', scheduled_date: '2026-06-08' })],
              fertilizer: [
                mockTask({
                  item_id: 3,
                  name: 'Feed',
                  scheduled_date: '2026-06-12'
                })
              ]
            }
          }
        ]
      })
    ]);

    expect(rows.map((row) => row.item.name)).toEqual(['Early', 'Feed', 'Late']);
    expect(rows[0]).toMatchObject({
      farmId: 2,
      farmName: 'Farm B',
      planId: 20,
      fieldName: 'Field 2',
      cropName: 'Carrot'
    });
  });

  it('excludes tasks without scheduled_date', () => {
    const rows = flattenCrossFarmSchedules([
      mockSource({
        farmId: 1,
        planId: 10,
        fields: [
          {
            name: 'Field 1',
            crop_name: 'Tomato',
            field_cultivation_id: 101,
            schedules: {
              general: [mockTask({ item_id: 1, scheduled_date: null })],
              fertilizer: []
            }
          }
        ]
      })
    ]);

    expect(rows).toHaveLength(0);
  });
});
