import { describe, expect, it } from 'vitest';

import { cropStageRequirementKind } from './crop-stage-requirement-kind';

describe('cropStageRequirementKind', () => {
  it('routes temperature requirements by marker fields', () => {
    expect(cropStageRequirementKind({ crop_stage_id: 1, max_temperature: 30 })).toBe('temperature');
    expect(cropStageRequirementKind({ crop_stage_id: 1, base_temperature: 10 })).toBe('temperature');
  });

  it('routes thermal requirements by required_gdd', () => {
    expect(cropStageRequirementKind({ crop_stage_id: 1, required_gdd: 100 })).toBe('thermal');
  });

  it('routes sunshine requirements by sunshine marker fields', () => {
    expect(cropStageRequirementKind({ crop_stage_id: 1, minimum_sunshine_hours: 4 })).toBe('sunshine');
  });

  it('routes nutrient requirements by uptake marker fields', () => {
    expect(cropStageRequirementKind({ crop_stage_id: 1, daily_uptake_n: 0.5 })).toBe('nutrient');
  });

  it('returns null for unknown shapes', () => {
    expect(cropStageRequirementKind(null)).toBeNull();
    expect(cropStageRequirementKind({ crop_stage_id: 1 })).toBeNull();
  });
});
