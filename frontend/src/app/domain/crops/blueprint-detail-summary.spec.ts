import { describe, expect, it } from 'vitest';
import { buildBlueprintDetailSummary } from './blueprint-detail-summary';
import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

function stage(order: number, name: string, requiredGdd: number): CropStage {
  return {
    id: order,
    crop_id: 1,
    name,
    order,
    thermal_requirement: { id: order, crop_stage_id: order, required_gdd: requiredGdd }
  };
}

const stages: CropStage[] = [
  stage(1, '育苗期', 300),
  stage(2, '定植期', 300)
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

describe('buildBlueprintDetailSummary', () => {
  it('groups blueprints by stage and omits empty lanes', () => {
    const summary = buildBlueprintDetailSummary(stages, [
      blueprint({
        id: 1,
        stage_order: 1,
        stage_name: '育苗期',
        gdd_trigger: 150,
        name: '播種'
      }),
      blueprint({
        id: 2,
        stage_order: 2,
        stage_name: '定植期',
        gdd_trigger: 450,
        name: '定植'
      })
    ]);

    expect(summary.lanes.map((lane) => lane.stageOrder)).toEqual([1, 2]);
    expect(summary.lanes[0].items.map((item) => item.taskName)).toEqual(['播種']);
    expect(summary.lanes[0].items[0].gddTrigger).toBe(150);
    expect(summary.lanes[1].items[0].taskName).toBe('定植');
    expect(summary.unsetTimingCount).toBe(0);
    expect(summary.issueCount).toBe(0);
    expect(summary.attentionCount).toBe(0);
  });

  it('counts unset timing when gdd_trigger is null', () => {
    const summary = buildBlueprintDetailSummary(stages, [
      blueprint({ id: 1, stage_order: 1, gdd_trigger: null, name: '灌水' })
    ]);

    expect(summary.unsetTimingCount).toBe(1);
    expect(summary.issueCount).toBe(0);
    expect(summary.attentionCount).toBe(1);
    expect(summary.lanes[0].items[0].gddError).toBeNull();
  });

  it('counts validation issues such as out_of_range', () => {
    const summary = buildBlueprintDetailSummary(stages, [
      blueprint({ id: 1, stage_order: 1, gdd_trigger: 500, name: '追肥' })
    ]);

    expect(summary.unsetTimingCount).toBe(0);
    expect(summary.issueCount).toBe(1);
    expect(summary.attentionCount).toBe(1);
    expect(summary.lanes[0].items[0].gddError).toBe('out_of_range');
    expect(summary.lanes[0].outOfRangeCount).toBe(1);
  });

  it('counts gdd_required for duplicate stage and task without timing', () => {
    const summary = buildBlueprintDetailSummary(stages, [
      blueprint({
        id: 1,
        stage_order: 1,
        agricultural_task_id: 5,
        gdd_trigger: 100,
        name: '播種'
      }),
      blueprint({
        id: 2,
        stage_order: 1,
        agricultural_task_id: 5,
        gdd_trigger: null,
        name: '播種'
      })
    ]);

    expect(summary.unsetTimingCount).toBe(0);
    expect(summary.issueCount).toBe(1);
    expect(summary.attentionCount).toBe(1);
    expect(summary.lanes[0].items[1].gddError).toBe('gdd_required');
  });

  it('resolves task name from agricultural_task when name is absent', () => {
    const summary = buildBlueprintDetailSummary(stages, [
      blueprint({
        id: 1,
        stage_order: 1,
        gdd_trigger: 100,
        agricultural_task: { id: 5, name: '除草' }
      })
    ]);

    expect(summary.lanes[0].items[0].taskName).toBe('除草');
  });

  it('sorts items within a lane by gdd_trigger ascending', () => {
    const summary = buildBlueprintDetailSummary(stages, [
      blueprint({ id: 1, stage_order: 1, gdd_trigger: 200, name: '後作業' }),
      blueprint({ id: 2, stage_order: 1, gdd_trigger: 50, name: '先作業' })
    ]);

    expect(summary.lanes[0].items.map((item) => item.taskName)).toEqual(['先作業', '後作業']);
  });

  it('aggregates out-of-range count per lane', () => {
    const summary = buildBlueprintDetailSummary(stages, [
      blueprint({ id: 1, stage_order: 1, gdd_trigger: 10, name: 'A' }),
      blueprint({ id: 2, stage_order: 1, gdd_trigger: 500, name: 'B' }),
      blueprint({ id: 3, stage_order: 2, gdd_trigger: 100, name: 'C' })
    ]);

    expect(summary.lanes[0].outOfRangeCount).toBe(1);
    expect(summary.lanes[1].outOfRangeCount).toBe(1);
  });

  it('groups lane items by gdd_trigger for badge display', () => {
    const summary = buildBlueprintDetailSummary(stages, [
      blueprint({ id: 1, stage_order: 2, gdd_trigger: 200, name: '定植' }),
      blueprint({ id: 2, stage_order: 2, gdd_trigger: 200, name: '耕耘' }),
      blueprint({ id: 3, stage_order: 2, gdd_trigger: 200, name: '基肥' })
    ]);

    const lane = summary.lanes.find((entry) => entry.stageOrder === 2);
    expect(lane?.gddGroups).toEqual([
      {
        gddTrigger: 200,
        items: [
          expect.objectContaining({ taskName: '定植', gddTrigger: 200 }),
          expect.objectContaining({ taskName: '耕耘', gddTrigger: 200 }),
          expect.objectContaining({ taskName: '基肥', gddTrigger: 200 })
        ]
      }
    ]);
  });

  it('creates separate gdd groups when triggers differ within a lane', () => {
    const summary = buildBlueprintDetailSummary(stages, [
      blueprint({ id: 1, stage_order: 1, gdd_trigger: 50, name: '播種' }),
      blueprint({ id: 2, stage_order: 1, gdd_trigger: 150, name: '灌水' }),
      blueprint({ id: 3, stage_order: 1, gdd_trigger: 150, name: '間引き' })
    ]);

    expect(summary.lanes[0].gddGroups).toEqual([
      {
        gddTrigger: 50,
        items: [expect.objectContaining({ taskName: '播種' })]
      },
      {
        gddTrigger: 150,
        items: [
          expect.objectContaining({ taskName: '灌水' }),
          expect.objectContaining({ taskName: '間引き' })
        ]
      }
    ]);
  });

  it('places unset timing items in a null gdd group at the end of the lane', () => {
    const summary = buildBlueprintDetailSummary(stages, [
      blueprint({ id: 1, stage_order: 1, gdd_trigger: 100, name: '除草' }),
      blueprint({ id: 2, stage_order: 1, gdd_trigger: null, name: '灌水' })
    ]);

    expect(summary.lanes[0].gddGroups).toEqual([
      {
        gddTrigger: 100,
        items: [expect.objectContaining({ taskName: '除草' })]
      },
      {
        gddTrigger: null,
        items: [expect.objectContaining({ taskName: '灌水', gddTrigger: null })]
      }
    ]);
  });
});
