import { describe, expect, it } from 'vitest';

import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';
import { countLinkedTaskScheduleBlueprints } from './stage-linked-blueprint-count';

function blueprint(stageOrder: number | null): CropTaskScheduleBlueprint {
  return {
    id: 1,
    crop_id: 1,
    agricultural_task_id: null,
    source_agricultural_task_id: null,
    stage_order: stageOrder,
    stage_name: null,
    gdd_trigger: null,
    gdd_tolerance: null,
    task_type: 'general',
    source: 'manual',
    priority: 1,
    amount: null,
    amount_unit: null,
    description: null,
    weather_dependency: null,
    time_per_sqm: null
  };
}

describe('countLinkedTaskScheduleBlueprints', () => {
  it('counts blueprints linked to the stage order', () => {
    const blueprints = [
      blueprint(1),
      blueprint(1),
      blueprint(2),
      blueprint(null)
    ];

    expect(countLinkedTaskScheduleBlueprints(1, blueprints)).toBe(2);
    expect(countLinkedTaskScheduleBlueprints(2, blueprints)).toBe(1);
    expect(countLinkedTaskScheduleBlueprints(3, blueprints)).toBe(0);
  });
});
