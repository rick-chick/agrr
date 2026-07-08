import { describe, expect, it } from 'vitest';
import { buildCropDetailStageBoard } from './crop-detail-stage-board';
import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

function stage(
  order: number,
  name: string,
  requiredGdd: number,
  optimalMin = 18,
  optimalMax = 30
): CropStage {
  return {
    id: order,
    crop_id: 1,
    name,
    order,
    temperature_requirement: {
      id: order,
      crop_stage_id: order,
      optimal_min: optimalMin,
      optimal_max: optimalMax
    },
    thermal_requirement: { id: order, crop_stage_id: order, required_gdd: requiredGdd }
  };
}

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

describe('buildCropDetailStageBoard', () => {
  const stages: CropStage[] = [
    stage(1, '育苗期', 800),
    stage(2, '定植期', 800)
  ];

  it('builds one column per stage with requirements even when no blueprints exist', () => {
    const board = buildCropDetailStageBoard(stages, []);

    expect(board.columns).toHaveLength(2);
    expect(board.columns[0]).toMatchObject({
      stageOrder: 1,
      stageName: '育苗期',
      requiredGdd: 800,
      optimalMin: 18,
      optimalMax: 30,
      cumulativeGddStart: 0,
      cumulativeGddEnd: 800,
      gddGroups: []
    });
    expect(board.columns[1]).toMatchObject({
      stageOrder: 2,
      cumulativeGddStart: 800,
      cumulativeGddEnd: 1600
    });
  });

  it('merges blueprint task groups into matching stage columns', () => {
    const board = buildCropDetailStageBoard(stages, [
      blueprint({ id: 1, stage_order: 1, gdd_trigger: 0, name: '播種' }),
      blueprint({ id: 2, stage_order: 2, gdd_trigger: 800, name: '定植' })
    ]);

    expect(board.columns[0].gddGroups).toHaveLength(1);
    expect(board.columns[0].gddGroups[0].items[0].taskName).toBe('播種');
    expect(board.columns[1].gddGroups[0].items[0].taskName).toBe('定植');
  });

  it('appends an unassigned column when blueprints lack stage_order', () => {
    const board = buildCropDetailStageBoard(stages, [
      blueprint({ id: 1, stage_order: null, gdd_trigger: null, name: '未割当' })
    ]);

    expect(board.columns).toHaveLength(3);
    expect(board.columns[2]).toMatchObject({
      stageOrder: null,
      stageName: null,
      requiredGdd: null,
      gddGroups: [
        expect.objectContaining({
          gddTrigger: null,
          items: [expect.objectContaining({ taskName: '未割当' })]
        })
      ]
    });
  });
});
