import type { CropTaskScheduleBlueprint } from '../crops/crop-task-schedule-blueprint';
import { BLUEPRINT_TIMING_PATCH_INTENT } from './blueprint-timing-adjustment-proposal';
import { buildBlueprintTimingAdjustmentProposals } from './build-blueprint-timing-adjustment-proposals';

function blueprint(
  overrides: Partial<CropTaskScheduleBlueprint> & Pick<CropTaskScheduleBlueprint, 'id' | 'task_type'>
): CropTaskScheduleBlueprint {
  return {
    crop_id: 1,
    agricultural_task_id: 1,
    source_agricultural_task_id: null,
    stage_order: 1,
    stage_name: '育苗',
    gdd_trigger: 100,
    gdd_tolerance: null,
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

describe('buildBlueprintTimingAdjustmentProposals', () => {
  it('builds patch proposal for general category blueprints', () => {
    const proposals = buildBlueprintTimingAdjustmentProposals(
      [
        {
          crop_id: 5,
          crop_name: 'Tomato',
          category: 'general',
          average_delta_days: 4,
          average_gdd_delta: 8,
          recorded_item_count: 2
        }
      ],
      new Map([
        [
          5,
          [
            blueprint({ id: 10, task_type: 'field_work', gdd_trigger: 120 }),
            blueprint({ id: 11, task_type: 'basal_fertilization', gdd_trigger: 80 })
          ]
        ]
      ])
    );

    expect(proposals).toHaveLength(1);
    expect(proposals[0].affectedBlueprintCount).toBe(1);
    expect(proposals[0].proposalBody.intent).toBe(BLUEPRINT_TIMING_PATCH_INTENT);
    expect(proposals[0].proposalBody.task_schedule_blueprints).toEqual([
      { blueprint_id: 10, gdd_trigger: 128 }
    ]);
  });

  it('skips proposals when no matching blueprints exist', () => {
    const proposals = buildBlueprintTimingAdjustmentProposals(
      [
        {
          crop_id: 5,
          crop_name: 'Tomato',
          category: 'general',
          average_delta_days: 4,
          average_gdd_delta: 8,
          recorded_item_count: 2
        }
      ],
      new Map([[5, [blueprint({ id: 10, task_type: 'basal_fertilization' })]]])
    );

    expect(proposals).toHaveLength(0);
  });
});
