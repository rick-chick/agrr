import { describe, it, expect } from 'vitest';
import {
  buildGanttCultivationPlanEndpoint,
  ganttPrivatePlanDataPath,
  ganttPublicPlanDataPath
} from './gantt-cultivation-plan-endpoints';

describe('gantt-cultivation-plan-endpoints', () => {
  it('builds private cultivation plan mutation paths', () => {
    expect(buildGanttCultivationPlanEndpoint('private', 7, 'adjust')).toBe(
      '/api/v1/plans/cultivation_plans/7/adjust'
    );
    expect(buildGanttCultivationPlanEndpoint('private', 7, 'remove_field', 88)).toBe(
      '/api/v1/plans/cultivation_plans/7/remove_field/88'
    );
  });

  it('builds public cultivation plan mutation paths', () => {
    expect(buildGanttCultivationPlanEndpoint('public', 9, 'add_crop')).toBe(
      '/api/v1/public_plans/cultivation_plans/9/add_crop'
    );
  });

  it('returns null for remove_field without field id', () => {
    expect(buildGanttCultivationPlanEndpoint('private', 7, 'remove_field')).toBeNull();
  });

  it('exposes plan data paths', () => {
    expect(ganttPrivatePlanDataPath(7)).toBe('/api/v1/plans/cultivation_plans/7/data');
    expect(ganttPublicPlanDataPath(9)).toBe('/api/v1/public_plans/cultivation_plans/9/data');
  });
});
