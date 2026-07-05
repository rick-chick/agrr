import { describe, expect, it } from 'vitest';
import { cropStageNameForOrder, stageNameForOrder } from './crop-stage-name';
import type { Crop } from './crop';

const cropWithStages: Crop = {
  id: 3,
  name: 'Tomato',
  is_reference: false,
  groups: [],
  crop_stages: [
    {
      id: 1,
      crop_id: 3,
      name: 'Vegetative',
      order: 1,
      temperature_requirement: {
        id: 1,
        crop_stage_id: 1,
        base_temperature: 10
      },
      thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 500 }
    },
    {
      id: 2,
      crop_id: 3,
      name: 'Reproductive',
      order: 2,
      temperature_requirement: {
        id: 2,
        crop_stage_id: 2,
        base_temperature: 10
      },
      thermal_requirement: { id: 2, crop_stage_id: 2, required_gdd: 300 }
    }
  ]
};

describe('stageNameForOrder', () => {
  const cropStages = [
    { order: 1, name: 'Vegetative' },
    { order: 2, name: 'Reproductive' }
  ];

  it('returns null when cropStages or stage order is missing', () => {
    expect(stageNameForOrder(undefined, 1)).toBeNull();
    expect(stageNameForOrder(cropStages, null)).toBeNull();
  });

  it('returns stage name for matching order', () => {
    expect(stageNameForOrder(cropStages, 1)).toBe('Vegetative');
    expect(stageNameForOrder(cropStages, 2)).toBe('Reproductive');
  });

  it('returns null when no stage matches the order', () => {
    expect(stageNameForOrder(cropStages, 99)).toBeNull();
    expect(stageNameForOrder([], 1)).toBeNull();
  });
});

describe('cropStageNameForOrder', () => {
  it('returns null when crop or stage order is missing', () => {
    expect(cropStageNameForOrder(null, 1)).toBeNull();
    expect(cropStageNameForOrder(cropWithStages, null)).toBeNull();
  });

  it('returns stage name for matching order', () => {
    expect(cropStageNameForOrder(cropWithStages, 1)).toBe('Vegetative');
    expect(cropStageNameForOrder(cropWithStages, 2)).toBe('Reproductive');
  });

  it('returns null when no stage matches the order', () => {
    expect(cropStageNameForOrder(cropWithStages, 99)).toBeNull();
    expect(cropStageNameForOrder({ ...cropWithStages, crop_stages: [] }, 1)).toBeNull();
  });
});
