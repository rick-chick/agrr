import { describe, expect, it } from 'vitest';
import { groupBlueprintsByStage } from './blueprint-stage-grouping';
import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

const stages: CropStage[] = [
  { id: 1, crop_id: 1, name: 'Germination', order: 1 },
  { id: 2, crop_id: 1, name: 'Vegetative', order: 2 },
  { id: 3, crop_id: 1, name: 'Harvest', order: 3 }
];

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

describe('groupBlueprintsByStage', () => {
  it('omits empty unassigned lane when stages exist', () => {
    const lanes = groupBlueprintsByStage(stages, []);

    expect(lanes.map((lane) => lane.stageOrder)).toEqual([1, 2, 3]);
    expect(lanes[0].stageName).toBe('Germination');
  });

  it('includes unassigned lane when it has blueprints', () => {
    const lanes = groupBlueprintsByStage(stages, [blueprint({ id: 10, stage_order: null })]);

    expect(lanes.map((lane) => lane.stageOrder)).toEqual([null, 1, 2, 3]);
    expect(lanes[0].blueprints.map((b) => b.id)).toEqual([10]);
  });

  it('places blueprints without stage_order in the unassigned lane', () => {
    const lanes = groupBlueprintsByStage(stages, [
      blueprint({ id: 10, stage_order: null }),
      blueprint({ id: 11, stage_order: 2, stage_name: 'Vegetative', gdd_trigger: 50 })
    ]);

    expect(lanes[0].blueprints.map((b) => b.id)).toEqual([10]);
    expect(lanes[2].blueprints.map((b) => b.id)).toEqual([11]);
  });

  it('sorts blueprints within a lane by draft GDD when present', () => {
    const lanes = groupBlueprintsByStage(
      stages,
      [
        blueprint({ id: 30, stage_order: 1, gdd_trigger: 120 }),
        blueprint({ id: 31, stage_order: 1, gdd_trigger: 50 }),
        blueprint({ id: 32, stage_order: 1, gdd_trigger: 200 })
      ],
      { 30: 10, 32: 80 }
    );

    expect(lanes[0].blueprints.map((b) => b.id)).toEqual([30, 31, 32]);
  });

  it('sorts blueprints within a lane by gdd_trigger ascending with null last', () => {
    const lanes = groupBlueprintsByStage(stages, [
      blueprint({ id: 30, stage_order: 1, gdd_trigger: 120 }),
      blueprint({ id: 31, stage_order: 1, gdd_trigger: null }),
      blueprint({ id: 32, stage_order: 1, gdd_trigger: 50 })
    ]);

    expect(lanes[0].blueprints.map((b) => b.id)).toEqual([32, 30, 31]);
  });

  it('uses id as tiebreaker when gdd_trigger is equal', () => {
    const lanes = groupBlueprintsByStage(stages, [
      blueprint({ id: 40, stage_order: 2, gdd_trigger: 100 }),
      blueprint({ id: 39, stage_order: 2, gdd_trigger: 100 })
    ]);

    expect(lanes[1].blueprints.map((b) => b.id)).toEqual([39, 40]);
  });

  it('returns only unassigned lane when crop has no stages', () => {
    const lanes = groupBlueprintsByStage([], [
      blueprint({ id: 50, gdd_trigger: 10 }),
      blueprint({ id: 51, stage_order: 1, gdd_trigger: 20 })
    ]);

    expect(lanes).toHaveLength(1);
    expect(lanes[0].stageOrder).toBeNull();
    expect(lanes[0].blueprints.map((b) => b.id)).toEqual([50, 51]);
  });

  it('keeps empty stage lanes for drop targets', () => {
    const lanes = groupBlueprintsByStage(stages, [
      blueprint({ id: 60, stage_order: 1, gdd_trigger: 10 })
    ]);

    expect(lanes).toHaveLength(3);
    expect(lanes[1].blueprints).toEqual([]);
    expect(lanes[2].blueprints).toEqual([]);
  });

  it('includes cumulative GDD range on stage lanes', () => {
    const stagesWithGdd: CropStage[] = [
      { id: 1, crop_id: 1, name: 'Germination', order: 1, thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 200 } },
      { id: 2, crop_id: 1, name: 'Vegetative', order: 2, thermal_requirement: { id: 2, crop_stage_id: 2, required_gdd: 300 } }
    ];
    const lanes = groupBlueprintsByStage(stagesWithGdd, []);

    expect(lanes[0]).toMatchObject({
      cumulativeGddStart: 0,
      cumulativeGddEnd: 200,
      gddRangeMissing: false
    });
    expect(lanes[1]).toMatchObject({
      cumulativeGddStart: 200,
      cumulativeGddEnd: 500,
      gddRangeMissing: false
    });
  });
});
