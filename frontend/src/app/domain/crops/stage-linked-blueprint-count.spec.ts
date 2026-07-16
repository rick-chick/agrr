import { describe, expect, it } from 'vitest';

import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';
import { countLinkedTaskScheduleBlueprintsForStage } from './stage-linked-blueprint-count';

function stage(id: number, order: number): CropStage {
  return {
    id,
    name: `Stage ${order}`,
    order,
    crop_id: 1
  };
}

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

describe('countLinkedTaskScheduleBlueprintsForStage', () => {
  it('counts blueprints linked to the stage resolved by id', () => {
    const stages = [stage(10, 1), stage(20, 2)];
    const blueprints = [
      { ...blueprint(1), id: 1 },
      { ...blueprint(1), id: 2 },
      { ...blueprint(2), id: 3 },
      { ...blueprint(null), id: 4 }
    ];

    expect(countLinkedTaskScheduleBlueprintsForStage(10, stages, blueprints)).toBe(2);
    expect(countLinkedTaskScheduleBlueprintsForStage(20, stages, blueprints)).toBe(1);
    expect(countLinkedTaskScheduleBlueprintsForStage(99, stages, blueprints)).toBe(0);
  });

  it('uses the current stage order after reorder so counts stay accurate', () => {
    const stages = [stage(10, 2), stage(20, 1)];
    const blueprints = [
      { ...blueprint(2), id: 1 },
      { ...blueprint(1), id: 2 }
    ];

    expect(countLinkedTaskScheduleBlueprintsForStage(10, stages, blueprints)).toBe(1);
    expect(countLinkedTaskScheduleBlueprintsForStage(20, stages, blueprints)).toBe(1);
  });
});
