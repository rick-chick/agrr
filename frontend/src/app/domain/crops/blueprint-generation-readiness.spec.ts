import { describe, expect, it } from 'vitest';
import { blueprintGenerationReadiness } from './blueprint-generation-readiness';
import type { Crop } from './crop';
import type { MastersCropTaskTemplate } from './masters-crop-task-template';

const baseCrop: Crop = {
  id: 1,
  name: 'Tomato',
  is_reference: false,
  groups: []
};

const template: MastersCropTaskTemplate = {
  id: 10,
  crop_id: 1,
  agricultural_task_id: 5,
  name: 'Weeding',
  required_tools: [],
  agricultural_task: { id: 5, name: 'Weeding', is_reference: false }
};

describe('blueprintGenerationReadiness', () => {
  it('is not ready when templates are missing', () => {
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
    expect(result.templatesReady).toBe(false);
    expect(result.stageRequirementsReady).toBe(true);
    expect(result.ready).toBe(false);
  });

  it('is not ready when no stage has base temperature and required GDD', () => {
    const result = blueprintGenerationReadiness(baseCrop, [template]);
    expect(result.templatesReady).toBe(true);
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
      [template]
    );
    expect(result.stageRequirementsReady).toBe(false);
    expect(result.ready).toBe(false);
  });

  it('is ready when templates and complete stage requirements exist', () => {
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
      [template]
    );
    expect(result.ready).toBe(true);
  });
});
