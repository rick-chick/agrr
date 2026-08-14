import { describe, expect, it } from 'vitest';
import {
  PLAN_CARRYOVER_FROM_QUERY_PARAM,
  PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY,
  buildPlanNewCarryoverFromNavigation,
  parseCarryoverFromPlanId
} from './plan-carryover-navigation';

describe('plan-carryover-navigation', () => {
  it('buildPlanNewCarryoverFromNavigation links to plans/new with carryoverFrom query param', () => {
    expect(buildPlanNewCarryoverFromNavigation(42)).toEqual({
      routerLink: ['/plans', 'new'],
      queryParams: { carryoverFrom: 42 }
    });
  });

  it('parseCarryoverFromPlanId reads carryoverFrom query param', () => {
    expect(parseCarryoverFromPlanId('7')).toBe(7);
    expect(parseCarryoverFromPlanId(null)).toBeNull();
    expect(parseCarryoverFromPlanId('')).toBeNull();
    expect(parseCarryoverFromPlanId('abc')).toBeNull();
  });

  it('exports shared query param and CTA i18n key', () => {
    expect(PLAN_CARRYOVER_FROM_QUERY_PARAM).toBe('carryoverFrom');
    expect(PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY).toBe('plans.carryover.next_plan_cta');
  });
});
