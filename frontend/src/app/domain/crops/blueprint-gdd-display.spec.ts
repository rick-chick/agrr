import { describe, expect, it } from 'vitest';
import {
  blueprintGddErrorsForDrafts,
  blueprintLaneOutOfRangeCounts,
  gddValueForBlueprint
} from './blueprint-gdd-display';
import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';
import type { BlueprintStageLane } from './blueprint-stage-grouping';

const stages: CropStage[] = [
  {
    id: 1,
    crop_id: 1,
    name: '定植期',
    order: 1,
    thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 200 }
  },
  {
    id: 2,
    crop_id: 1,
    name: '生育期',
    order: 2,
    thermal_requirement: { id: 2, crop_stage_id: 2, required_gdd: 300 }
  }
];

function blueprint(
  overrides: Partial<CropTaskScheduleBlueprint> & Pick<CropTaskScheduleBlueprint, 'id'>
): CropTaskScheduleBlueprint {
  return {
    crop_id: 1,
    agricultural_task_id: 1,
    source_agricultural_task_id: null,
    stage_order: 1,
    stage_name: '定植期',
    gdd_trigger: 50,
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

describe('gddValueForBlueprint', () => {
  it('returns draft value when present', () => {
    const bp = blueprint({ id: 10, gdd_trigger: 50 });
    expect(gddValueForBlueprint(bp, { 10: 120 })).toBe(120);
  });

  it('falls back to persisted gdd_trigger when draft is absent', () => {
    const bp = blueprint({ id: 10, gdd_trigger: 50 });
    expect(gddValueForBlueprint(bp, {})).toBe(50);
  });
});

describe('blueprintGddErrorsForDrafts', () => {
  it('returns out_of_range when draft exceeds stage cumulative band', () => {
    const blueprints = [blueprint({ id: 10, gdd_trigger: 50 })];
    expect(blueprintGddErrorsForDrafts(stages, blueprints, { 10: 500 })).toEqual({
      10: 'out_of_range'
    });
  });
});

describe('blueprintLaneOutOfRangeCounts', () => {
  it('counts out-of-range blueprints per stage lane', () => {
    const lanes: BlueprintStageLane[] = [
      {
        stageOrder: 1,
        stageName: '定植期',
        cumulativeGddStart: 0,
        cumulativeGddEnd: 200,
        gddRangeMissing: false,
        blueprints: [
          blueprint({ id: 10, gdd_trigger: 50 }),
          blueprint({ id: 11, gdd_trigger: 500 })
        ]
      }
    ];
    expect(blueprintLaneOutOfRangeCounts(stages, lanes, { 10: 50, 11: 500 })).toEqual({ 1: 1 });
  });
});
