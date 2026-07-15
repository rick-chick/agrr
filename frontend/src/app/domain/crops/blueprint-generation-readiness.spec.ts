import { describe, expect, it } from 'vitest';
import {
  blueprintGenerationReadiness,
  stageRequirementsComplete
} from './blueprint-generation-readiness';
import type { Crop } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

const baseCrop: Crop = {
  id: 1,
  name: 'Tomato',
  is_reference: false,
  groups: []
};

const blueprint: CropTaskScheduleBlueprint = {
  id: 10,
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
};

describe('stageRequirementsComplete', () => {
  it('is false when base temperature and required GDD are missing', () => {
    expect(
      stageRequirementsComplete({
        id: 1,
        crop_id: 1,
        name: 'Vegetative',
        order: 1
      })
    ).toBe(false);
  });

  it('is false when only required GDD is present', () => {
    expect(
      stageRequirementsComplete({
        id: 1,
        crop_id: 1,
        name: 'Vegetative',
        order: 1,
        thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 }
      })
    ).toBe(false);
  });

  it('is true when base temperature and required GDD are present', () => {
    expect(
      stageRequirementsComplete({
        id: 1,
        crop_id: 1,
        name: 'Vegetative',
        order: 1,
        temperature_requirement: {
          id: 1,
          crop_stage_id: 1,
          base_temperature: 10
        },
        thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 }
      })
    ).toBe(true);
  });
});

describe('blueprintGenerationReadiness', () => {
  it('is not ready when blueprints are missing', () => {
    const result = blueprintGenerationReadiness(
      {
        ...baseCrop,
        crop_stages: [
          {
            id: 1,
            crop_id: 1,
            name: 'Vegetative',
            order: 1,
            temperature_requirement: {
              id: 1,
              crop_stage_id: 1,
              base_temperature: 10
            },
            thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 }
          }
        ]
      },
      []
    );
    expect(result.blueprintsReady).toBe(false);
    expect(result.stageRequirementsReady).toBe(true);
    expect(result.ready).toBe(false);
  });

  it('is not ready when no stage has base temperature and required GDD', () => {
    const result = blueprintGenerationReadiness(baseCrop, [blueprint]);
    expect(result.blueprintsReady).toBe(true);
    expect(result.stageRequirementsReady).toBe(false);
    expect(result.ready).toBe(false);
  });

  it('is not ready when stage has GDD but missing base temperature', () => {
    const result = blueprintGenerationReadiness(
      {
        ...baseCrop,
        crop_stages: [
          {
            id: 1,
            crop_id: 1,
            name: 'Vegetative',
            order: 1,
            thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 }
          }
        ]
      },
      [blueprint]
    );
    expect(result.stageRequirementsReady).toBe(false);
    expect(result.ready).toBe(false);
  });

  it('is not ready when only fertilizer blueprints exist', () => {
    const result = blueprintGenerationReadiness(
      {
        ...baseCrop,
        crop_stages: [
          {
            id: 1,
            crop_id: 1,
            name: 'Vegetative',
            order: 1,
            temperature_requirement: {
              id: 1,
              crop_stage_id: 1,
              base_temperature: 10
            },
            thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 }
          }
        ]
      },
      [
        {
          ...blueprint,
          id: 11,
          task_type: 'basal_fertilization',
          name: 'Basal fertilization'
        }
      ]
    );
    expect(result.blueprintsReady).toBe(false);
    expect(result.ready).toBe(false);
  });

  it('is ready when blueprints and complete stage requirements exist', () => {
    const result = blueprintGenerationReadiness(
      {
        ...baseCrop,
        crop_stages: [
          {
            id: 1,
            crop_id: 1,
            name: 'Vegetative',
            order: 1,
            temperature_requirement: {
              id: 1,
              crop_stage_id: 1,
              base_temperature: 10
            },
            thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 }
          }
        ]
      },
      [blueprint]
    );
    expect(result.ready).toBe(true);
  });
});
