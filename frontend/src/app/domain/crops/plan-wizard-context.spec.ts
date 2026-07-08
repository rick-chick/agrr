import { describe, expect, it } from 'vitest';
import {
  cropPlanWizardQueryParams,
  parsePlanWizardReturnTab,
  planWizardReturnPath
} from './plan-wizard-context';

describe('parsePlanWizardReturnTab', () => {
  it('defaults to task_schedule', () => {
    expect(parsePlanWizardReturnTab(null)).toBe('task_schedule');
    expect(parsePlanWizardReturnTab(undefined)).toBe('task_schedule');
    expect(parsePlanWizardReturnTab('other')).toBe('task_schedule');
  });

  it('accepts work', () => {
    expect(parsePlanWizardReturnTab('work')).toBe('work');
  });
});

describe('planWizardReturnPath', () => {
  it('routes to work or task_schedule tab', () => {
    expect(planWizardReturnPath(7, 'work')).toEqual(['/plans', 7, 'work']);
    expect(planWizardReturnPath(7, 'task_schedule')).toEqual(['/plans', 7, 'task_schedule']);
  });
});

describe('cropPlanWizardQueryParams', () => {
  it('includes fromPlan and returnTo', () => {
    expect(cropPlanWizardQueryParams(7, 'task_schedule')).toEqual({
      fromPlan: 7,
      returnTo: 'task_schedule'
    });
  });
});
