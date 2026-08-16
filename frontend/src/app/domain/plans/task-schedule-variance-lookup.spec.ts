import { describe, expect, it } from 'vitest';
import { TaskScheduleItem } from '../../models/plans/task-schedule';
import {
  collectTaskScheduleItemsForField,
  taskScheduleVarianceByItemId
} from './task-schedule-variance-lookup';

describe('task-schedule-variance-lookup', () => {
  it('collects schedule items for a field cultivation', () => {
    const items = collectTaskScheduleItemsForField(
      [
        {
          id: 1,
          name: 'Field A',
          crop_name: 'Tomato',
          area_sqm: 100,
          field_cultivation_id: 10,
          crop_id: 1,
          schedules: {
            general: [{ item_id: 1 } as TaskScheduleItem],
            fertilizer: [],
            pest_control: [],
            unscheduled: []
          }
        }
      ],
      10
    );

    expect(items).toHaveLength(1);
    expect(items[0].item_id).toBe(1);
  });

  it('includes pest_control items when collecting schedule items for a field', () => {
    const items = collectTaskScheduleItemsForField(
      [
        {
          id: 1,
          name: 'Field A',
          crop_name: 'Tomato',
          area_sqm: 100,
          field_cultivation_id: 10,
          crop_id: 1,
          schedules: {
            general: [],
            fertilizer: [],
            pest_control: [{ item_id: 99 } as TaskScheduleItem],
            unscheduled: []
          }
        }
      ],
      10
    );

    expect(items).toHaveLength(1);
    expect(items[0].item_id).toBe(99);
  });

  it('maps variance fields by item id', () => {
    const map = taskScheduleVarianceByItemId([
      { item_id: 1, delta_days: 2, gdd_delta: 10.5 } as TaskScheduleItem
    ]);

    expect(map.get(1)).toEqual({ deltaDays: 2, gddDelta: 10.5 });
  });
});
