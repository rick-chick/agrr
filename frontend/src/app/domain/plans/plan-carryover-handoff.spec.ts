import { describe, expect, it } from 'vitest';
import {
  PLAN_CARRYOVER_FROM_QUERY_PARAM,
  buildPlanNewCarryoverFromNavigation,
  planCarryoverNextPlanCtaVisible
} from './plan-carryover-handoff';

describe('plan-carryover-handoff', () => {
  it('uses carryoverFrom as the plan-new query param name', () => {
    expect(PLAN_CARRYOVER_FROM_QUERY_PARAM).toBe('carryoverFrom');
  });

  it('buildPlanNewCarryoverFromNavigation links to plan-new with carryoverFrom', () => {
    expect(buildPlanNewCarryoverFromNavigation(7)).toEqual({
      routerLink: ['/plans', 'new'],
      queryParams: { carryoverFrom: 7 }
    });
  });

  it('planCarryoverNextPlanCtaVisible is true when learning snapshot exists', () => {
    expect(
      planCarryoverNextPlanCtaVisible({
        hasLearningSnapshot: true,
        loopComplete: false
      })
    ).toBe(true);
  });

  it('planCarryoverNextPlanCtaVisible is true when learn loop is complete', () => {
    expect(
      planCarryoverNextPlanCtaVisible({
        hasLearningSnapshot: false,
        loopComplete: true
      })
    ).toBe(true);
  });

  it('planCarryoverNextPlanCtaVisible is false without learning data', () => {
    expect(
      planCarryoverNextPlanCtaVisible({
        hasLearningSnapshot: false,
        loopComplete: false
      })
    ).toBe(false);
  });
});
