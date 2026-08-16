import type { CropTaskScheduleBlueprint } from '../crops/crop-task-schedule-blueprint';
import { BLUEPRINT_AMOUNT_PATCH_INTENT } from './blueprint-amount-adjustment-proposal';
import { buildBlueprintAmountAdjustmentProposals } from './build-blueprint-amount-adjustment-proposals';

function blueprint(
  overrides: Partial<CropTaskScheduleBlueprint> & Pick<CropTaskScheduleBlueprint, 'id' | 'task_type'>
): CropTaskScheduleBlueprint {
  return {
    crop_id: 1,
    agricultural_task_id: 1,
    source_agricultural_task_id: null,
    stage_order: 1,
    stage_name: 'Vegetative',
    gdd_trigger: 100,
    gdd_tolerance: null,
    source: 'manual',
    priority: 1,
    amount: 2,
    amount_unit: 'kg',
    description: null,
    weather_dependency: null,
    time_per_sqm: null,
    ...overrides
  };
}

describe('buildBlueprintAmountAdjustmentProposals', () => {
  it('builds amount patch proposal for matching task_type blueprints', () => {
    const proposals = buildBlueprintAmountAdjustmentProposals(
      [
        {
          crop_id: 5,
          crop_name: 'Tomato',
          category: 'fertilizer',
          task_type: 'fertilize',
          stage_order: 1,
          stage_name: 'Vegetative',
          average_amount_delta: 0.5,
          recorded_item_count: 2,
          amount_unit: 'kg'
        }
      ],
      new Map([
        [
          5,
          [
            blueprint({ id: 10, task_type: 'fertilize', amount: 2, amount_unit: 'kg' }),
            blueprint({ id: 11, task_type: 'field_work', amount: 1, amount_unit: 'kg' })
          ]
        ]
      ])
    );

    expect(proposals).toHaveLength(1);
    expect(proposals[0].affectedBlueprintCount).toBe(1);
    expect(proposals[0].proposalBody.intent).toBe(BLUEPRINT_AMOUNT_PATCH_INTENT);
    expect(proposals[0].proposalBody.task_schedule_blueprints).toEqual([
      { blueprint_id: 10, amount: 2.5, amount_unit: 'kg' }
    ]);
  });

  it('skips proposals when no matching blueprints exist', () => {
    const proposals = buildBlueprintAmountAdjustmentProposals(
      [
        {
          crop_id: 5,
          crop_name: 'Tomato',
          category: 'fertilizer',
          task_type: 'fertilize',
          stage_order: 1,
          stage_name: 'Vegetative',
          average_amount_delta: 0.5,
          recorded_item_count: 2,
          amount_unit: 'kg'
        }
      ],
      new Map([[5, [blueprint({ id: 10, task_type: 'field_work' })]]])
    );

    expect(proposals).toHaveLength(0);
  });
});
