import { describe, expect, it } from 'vitest';

import {
  createGddPlaceholder,
  gddPlaceholderForBlueprint,
  gddValidationMessage
} from './crop-blueprint-gdd-i18n';
import type { CropStage } from '../../domain/crops/crop';
import type { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import type { StageCumulativeGddRange } from '../../domain/crops/stage-cumulative-gdd';

function stage(order: number, requiredGdd: number | null): CropStage {
  return {
    id: order,
    crop_id: 1,
    name: `Stage ${order}`,
    order,
    thermal_requirement:
      requiredGdd == null
        ? undefined
        : { id: order, crop_stage_id: order, required_gdd: requiredGdd }
  };
}

function blueprint(
  overrides: Partial<CropTaskScheduleBlueprint> & Pick<CropTaskScheduleBlueprint, 'id'>
): CropTaskScheduleBlueprint {
  return {
    crop_id: 1,
    agricultural_task_id: 1,
    source_agricultural_task_id: null,
    stage_order: 1,
    stage_name: 'Stage 1',
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

describe('gddValidationMessage', () => {
  const instant = (key: string, params?: Record<string, unknown>) =>
    params ? `${key}:${JSON.stringify(params)}` : key;

  it('returns missing_stage message key', () => {
    expect(gddValidationMessage(instant, 'missing_stage', [], null)).toBe(
      'crops.show.blueprint_gdd_errors.missing_stage'
    );
  });

  it('returns stage_gdd_missing message key', () => {
    expect(gddValidationMessage(instant, 'stage_gdd_missing', [stage(1, 200)], 1)).toBe(
      'crops.show.blueprint_gdd_errors.stage_gdd_missing'
    );
  });

  it('returns gdd_required message key', () => {
    expect(gddValidationMessage(instant, 'gdd_required', [], null)).toBe(
      'crops.show.blueprint_gdd_errors.gdd_required'
    );
  });

  it('returns out_of_range message with cumulative GDD bounds', () => {
    const stages = [stage(1, 200), stage(2, 300)];
    const message = gddValidationMessage(instant, 'out_of_range', stages, 2);
    expect(message).toBe(
      'crops.show.blueprint_gdd_errors.out_of_range:{"start":200,"end":500}'
    );
  });
});

describe('gddPlaceholderForBlueprint', () => {
  const instant = (key: string) => `tr:${key}`;

  it('returns null when blueprint already has gdd_trigger', () => {
    const result = gddPlaceholderForBlueprint(
      instant,
      blueprint({ id: 1, gdd_trigger: 50 }),
      [stage(1, 200)]
    );
    expect(result).toBeNull();
  });

  it('returns placeholder translation when stage is unset', () => {
    const result = gddPlaceholderForBlueprint(
      instant,
      blueprint({ id: 1, stage_order: null }),
      [stage(1, 200)]
    );
    expect(result).toBe('tr:crops.show.gdd_trigger_placeholder');
  });

  it('returns cumulative GDD start when stage range is known', () => {
    const result = gddPlaceholderForBlueprint(
      instant,
      blueprint({ id: 1, stage_order: 2, gdd_trigger: null }),
      [stage(1, 200), stage(2, 300)]
    );
    expect(result).toBe('200');
  });
});

describe('createGddPlaceholder', () => {
  const instant = (key: string) => `tr:${key}`;

  it('returns placeholder translation when range is missing', () => {
    expect(createGddPlaceholder(instant, null)).toBe('tr:crops.show.gdd_trigger_placeholder');
    expect(
      createGddPlaceholder(instant, {
        cumulativeGddStart: null,
        cumulativeGddEnd: null,
        gddRangeMissing: true
      })
    ).toBe('tr:crops.show.gdd_trigger_placeholder');
  });

  it('returns cumulative GDD start as string when range is valid', () => {
    const range: StageCumulativeGddRange = {
      cumulativeGddStart: 150,
      cumulativeGddEnd: 350,
      gddRangeMissing: false
    };
    expect(createGddPlaceholder(instant, range)).toBe('150');
  });
});
