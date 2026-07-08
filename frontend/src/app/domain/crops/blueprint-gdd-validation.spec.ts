import { describe, expect, it } from 'vitest';
import { blueprintGddValidationError } from './blueprint-gdd-validation';
import type { CropStage } from './crop';

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

const stages = [stage(1, 200), stage(2, 300)];

describe('blueprintGddValidationError', () => {
  it('returns missing_stage when stage is unset', () => {
    expect(blueprintGddValidationError(stages, null, 100)).toBe('missing_stage');
  });

  it('returns out_of_range when gdd is outside the stage band', () => {
    expect(blueprintGddValidationError(stages, 1, 250)).toBe('out_of_range');
  });

  it('returns stage_gdd_missing when stage required gdd is unset', () => {
    expect(blueprintGddValidationError([stage(1, null)], 1, 10)).toBe('stage_gdd_missing');
  });

  it('returns null when gdd is valid', () => {
    expect(blueprintGddValidationError(stages, 1, 120)).toBeNull();
  });

  it('returns null when gdd is null (unset timing allowed until save)', () => {
    expect(blueprintGddValidationError(stages, 1, null)).toBeNull();
  });
});
