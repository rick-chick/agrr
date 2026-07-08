import { describe, expect, it } from 'vitest';
import {
  resolveBlueprintDropUpdate,
  resolveBlueprintGddFromDrop
} from './resolve-blueprint-gdd-from-drop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

function blueprint(
  overrides: Partial<CropTaskScheduleBlueprint> & Pick<CropTaskScheduleBlueprint, 'id'>
): CropTaskScheduleBlueprint {
  return {
    crop_id: 1,
    agricultural_task_id: 5,
    source_agricultural_task_id: null,
    stage_order: null,
    stage_name: null,
    gdd_trigger: null,
    gdd_tolerance: null,
    task_type: 'field_work',
    source: 'manual',
    priority: 1,
    amount: null,
    amount_unit: null,
    description: null,
    weather_dependency: null,
    time_per_sqm: null,
    ...overrides
  };
}

describe('resolveBlueprintGddFromDrop', () => {
  it('copies gdd_trigger from the card immediately before the drop index', () => {
    const lane = [
      blueprint({ id: 1, gdd_trigger: 50 }),
      blueprint({ id: 2, gdd_trigger: 120 }),
      blueprint({ id: 3, gdd_trigger: 200 })
    ];

    expect(
      resolveBlueprintGddFromDrop({
        laneBlueprints: lane,
        draggedBlueprint: lane[2],
        dropIndex: 1
      })
    ).toBe(50);
  });

  it('copies gdd_trigger from the right neighbor when dropped at index 0', () => {
    const lane = [
      blueprint({ id: 1, gdd_trigger: 80 }),
      blueprint({ id: 2, gdd_trigger: 120 })
    ];

    expect(
      resolveBlueprintGddFromDrop({
        laneBlueprints: lane,
        draggedBlueprint: lane[1],
        dropIndex: 0
      })
    ).toBe(80);
  });

  it('returns null when the lane contains only the dragged card', () => {
    expect(
      resolveBlueprintGddFromDrop({
        laneBlueprints: [blueprint({ id: 1, gdd_trigger: 100 })],
        draggedBlueprint: blueprint({ id: 1, gdd_trigger: 100 }),
        dropIndex: 0
      })
    ).toBeNull();
  });

  it('returns null when the copy source gdd_trigger is null', () => {
    const lane = [
      blueprint({ id: 1, gdd_trigger: null }),
      blueprint({ id: 2, gdd_trigger: 120 })
    ];

    expect(
      resolveBlueprintGddFromDrop({
        laneBlueprints: lane,
        draggedBlueprint: lane[1],
        dropIndex: 1
      })
    ).toBeNull();
  });
});

describe('resolveBlueprintDropUpdate', () => {
  it('commits gdd change on same-lane reorder', () => {
    const dragged = blueprint({ id: 3, stage_order: 1, gdd_trigger: 200 });
    const lane = [
      blueprint({ id: 1, stage_order: 1, gdd_trigger: 50 }),
      blueprint({ id: 2, stage_order: 1, gdd_trigger: 120 }),
      dragged
    ];

    const result = resolveBlueprintDropUpdate({
      dragged,
      targetStageOrder: 1,
      laneBlueprints: lane,
      dropIndex: 1
    });

    expect(result).toEqual({
      shouldCommit: true,
      gddTrigger: 50
    });
  });

  it('commits stage and gdd on cross-lane drop', () => {
    const dragged = blueprint({ id: 1, stage_order: null, gdd_trigger: 10 });
    const targetLane = [
      blueprint({ id: 2, stage_order: 1, gdd_trigger: 50 }),
      blueprint({ id: 3, stage_order: 1, gdd_trigger: 120 })
    ];

    const result = resolveBlueprintDropUpdate({
      dragged,
      targetStageOrder: 1,
      laneBlueprints: [...targetLane, dragged],
      dropIndex: 1
    });

    expect(result).toEqual({
      shouldCommit: true,
      stageOrder: 1,
      gddTrigger: 50
    });
  });

  it('does not commit when stage and gdd are unchanged', () => {
    const dragged = blueprint({ id: 2, stage_order: 1, gdd_trigger: 50 });
    const lane = [
      blueprint({ id: 1, stage_order: 1, gdd_trigger: 50 }),
      dragged
    ];

    const result = resolveBlueprintDropUpdate({
      dragged,
      targetStageOrder: 1,
      laneBlueprints: lane,
      dropIndex: 1
    });

    expect(result).toEqual({ shouldCommit: false });
  });
});
