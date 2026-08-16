import { describe, it, expect } from 'vitest';
import {
  buildPublicPlanSaveNextStepRoute,
  isPublicPlanSaveStepComplete,
  PUBLIC_PLAN_PRIVATE_VALUE_ITEMS,
  PUBLIC_PLAN_SAVE_NEXT_STEPS
} from './public-plan-results-upsell.content';

describe('public-plan-results-upsell.content', () => {
  it('defines three private value preview items', () => {
    expect(PUBLIC_PLAN_PRIVATE_VALUE_ITEMS).toHaveLength(3);
  });

  it('defines three save next steps', () => {
    expect(PUBLIC_PLAN_SAVE_NEXT_STEPS).toHaveLength(3);
  });

  it('builds post-save routes only when savedPlanId exists', () => {
    expect(buildPublicPlanSaveNextStepRoute('task_schedule', null)).toBeNull();
    expect(buildPublicPlanSaveNextStepRoute('task_schedule', 7)).toEqual([
      '/plans',
      7,
      'task_schedule'
    ]);
    expect(buildPublicPlanSaveNextStepRoute('work_record', 7)).toEqual([
      '/plans',
      7,
      'work_records'
    ]);
    expect(buildPublicPlanSaveNextStepRoute('save', 7)).toBeNull();
  });

  it('marks only save step complete when savedPlanId is set', () => {
    expect(isPublicPlanSaveStepComplete('save', null)).toBe(false);
    expect(isPublicPlanSaveStepComplete('save', 1)).toBe(true);
    expect(isPublicPlanSaveStepComplete('task_schedule', 1)).toBe(false);
  });
});
