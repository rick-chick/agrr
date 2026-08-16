import { describe, expect, it } from 'vitest';
import {
  buildPlanCreateReadiness,
  isWeatherReady,
  type PlanCreateCropReadiness,
  type PlanCreateReadinessInput
} from './plan-create-readiness';
import type { Crop } from '../crops/crop';
import type { CropTaskScheduleBlueprint } from '../crops/crop-task-schedule-blueprint';

const userCrop: Crop = {
  id: 1,
  name: 'Tomato',
  is_reference: false,
  groups: [],
  crop_stages: [
    {
      id: 10,
      crop_id: 1,
      name: 'Vegetative',
      order: 1,
      temperature_requirement: { id: 1, crop_stage_id: 10, base_temperature: 10 },
      thermal_requirement: { id: 1, crop_stage_id: 10, required_gdd: 100 }
    }
  ]
};

const referenceCrop: Crop = {
  id: 99,
  name: 'Reference Tomato',
  is_reference: true,
  groups: []
};

const readyBlueprints: CropTaskScheduleBlueprint[] = [
  {
    id: 1,
    crop_id: 1,
    agricultural_task_id: 5,
    source_agricultural_task_id: null,
    stage_order: 1,
    stage_name: 'Vegetative',
    gdd_trigger: 100,
    gdd_tolerance: null,
    task_type: 'field_work',
    source: 'manual',
    priority: 1,
    amount: null,
    amount_unit: null,
    description: null,
    weather_dependency: null,
    time_per_sqm: null,
    name: 'Weeding',
    agricultural_task: { id: 5, name: 'Weeding' }
  },
  {
    id: 2,
    crop_id: 1,
    agricultural_task_id: 6,
    source_agricultural_task_id: null,
    stage_order: 1,
    stage_name: 'Vegetative',
    gdd_trigger: 100,
    gdd_tolerance: null,
    task_type: 'basal_fertilization',
    source: 'manual',
    priority: 1,
    amount: null,
    amount_unit: null,
    description: null,
    weather_dependency: null,
    time_per_sqm: null,
    name: 'Basal',
    agricultural_task: { id: 6, name: 'Basal' }
  }
];

describe('isWeatherReady', () => {
  it('is true when weather_data_status is completed', () => {
    expect(isWeatherReady('completed')).toBe(true);
  });

  it('is false for pending, fetching, or failed', () => {
    expect(isWeatherReady('pending')).toBe(false);
    expect(isWeatherReady('fetching')).toBe(false);
    expect(isWeatherReady('failed')).toBe(false);
    expect(isWeatherReady(undefined)).toBe(false);
  });
});

describe('buildPlanCreateReadiness', () => {
  const baseInput = (overrides: Partial<PlanCreateReadinessInput> = {}): PlanCreateReadinessInput => ({
    farmId: 1,
    fieldCount: 2,
    hasValidFields: true,
    weatherStatus: 'completed',
    crops: [],
    cropBlueprints: {},
    ...overrides
  });

  it('reports fields, weather, and crops as not ready when all missing', () => {
    const result = buildPlanCreateReadiness(
      baseInput({
        fieldCount: 0,
        hasValidFields: false,
        weatherStatus: 'pending',
        crops: []
      })
    );

    expect(result.fieldsReady).toBe(false);
    expect(result.weatherReady).toBe(false);
    expect(result.cropsReady).toBe(false);
    expect(result.allReady).toBe(false);
    expect(result.cropSummaries).toEqual([]);
  });

  it('marks crops ready when at least one user crop has blueprint readiness', () => {
    const result = buildPlanCreateReadiness(
      baseInput({
        crops: [userCrop, referenceCrop],
        cropBlueprints: { 1: readyBlueprints }
      })
    );

    expect(result.cropsReady).toBe(true);
    expect(result.cropSummaries).toHaveLength(1);
    expect(result.cropSummaries[0]).toMatchObject({
      cropId: 1,
      name: 'Tomato',
      ready: true
    } satisfies Partial<PlanCreateCropReadiness>);
    expect(result.allReady).toBe(true);
  });

  it('excludes reference crops from summaries', () => {
    const result = buildPlanCreateReadiness(
      baseInput({
        crops: [referenceCrop],
        cropBlueprints: {}
      })
    );

    expect(result.cropSummaries).toEqual([]);
    expect(result.cropsReady).toBe(false);
  });

  it('allReady requires fields, weather, and at least one ready user crop', () => {
    const withoutCrops = buildPlanCreateReadiness(
      baseInput({
        crops: [],
        cropBlueprints: {}
      })
    );
    expect(withoutCrops.allReady).toBe(false);

    const withCrop = buildPlanCreateReadiness(
      baseInput({
        crops: [userCrop],
        cropBlueprints: { 1: readyBlueprints }
      })
    );
    expect(withCrop.allReady).toBe(true);
  });
});
