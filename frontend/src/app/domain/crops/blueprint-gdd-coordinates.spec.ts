import { describe, expect, it } from 'vitest';
import { blueprintGddDraftsFromBlueprints } from './blueprint-gdd-coordinates';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

function blueprint(id: number, gdd: number | null): CropTaskScheduleBlueprint {
  return {
    id,
    crop_id: 1,
    agricultural_task_id: 1,
    source_agricultural_task_id: null,
    stage_order: 1,
    stage_name: 'S1',
    gdd_trigger: gdd,
    gdd_tolerance: null,
    task_type: 'field_work',
    source: 'manual',
    priority: 1,
    amount: null,
    amount_unit: null,
    description: null,
    weather_dependency: null,
    time_per_sqm: null
  };
}

describe('blueprintGddDraftsFromBlueprints', () => {
  it('copies absolute gdd_trigger values into drafts', () => {
    expect(blueprintGddDraftsFromBlueprints([blueprint(1, 0), blueprint(2, 350)])).toEqual({
      1: 0,
      2: 350
    });
  });
});
