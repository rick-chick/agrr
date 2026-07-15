import { describe, it, expect } from 'vitest';

import { CROP_STAGES_PROVIDERS } from './crop-stages.providers';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from './crop-task-schedule-blueprint-gateway';

describe('CROP_STAGES_PROVIDERS', () => {
  it('registers CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY for LoadCropTaskScheduleBlueprintsUseCase', () => {
    const hasGateway = CROP_STAGES_PROVIDERS.some(
      (provider) =>
        typeof provider === 'object' &&
        provider !== null &&
        'provide' in provider &&
        provider.provide === CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY
    );

    expect(hasGateway).toBe(true);
  });
});
