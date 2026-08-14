import { beforeEach, describe, expect, it } from 'vitest';
import {
  clearLearnProposalApplicationProgressCache,
  markStageGddProposalAppliedPending
} from './learn-proposal-application-progress';
import { resolveLearnLoopNavBadge } from './learn-loop-nav-badge';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

const PLAN_ID = 7;

function varianceSummary(
  overrides: Partial<PlanVsActualSummary> = {}
): PlanVsActualSummary {
  return {
    plan_id: PLAN_ID,
    unrecorded_count: 0,
    categories: [],
    top_variance_items: [],
    stage_gdd_calibration_proposals: [],
    blueprint_timing_adjustment_proposals: [],
    action_required_items: [],
    ...overrides
  };
}

describe('resolveLearnLoopNavBadge', () => {
  beforeEach(() => {
    clearLearnProposalApplicationProgressCache();
  });

  it('returns proposal_count badge when proposals are not started', () => {
    const badge = resolveLearnLoopNavBadge({
      planId: PLAN_ID,
      varianceSummary: varianceSummary({
        stage_gdd_calibration_proposals: [
          {
            crop_id: 1,
            crop_name: 'Tomato',
            stage_order: 1,
            stage_name: 'Vegetative',
            average_gdd_delta: 10,
            recorded_item_count: 2
          }
        ]
      }),
      learningSnapshot: null
    });

    expect(badge).toEqual({ kind: 'proposal_count', count: 1 });
  });

  it('returns phase badge when proposals are in progress but none are not_started', () => {
    markStageGddProposalAppliedPending(PLAN_ID, {
      cropId: 1,
      stageId: 1
    });

    const badge = resolveLearnLoopNavBadge({
      planId: PLAN_ID,
      varianceSummary: varianceSummary({
        stage_gdd_calibration_proposals: [
          {
            crop_id: 1,
            crop_name: 'Tomato',
            stage_order: 1,
            stage_name: 'Vegetative',
            average_gdd_delta: 10,
            recorded_item_count: 2
          }
        ]
      }),
      learningSnapshot: null
    });

    expect(badge).toEqual({ kind: 'phase', phaseId: 'reorganize' });
  });

  it('returns observe phase badge when action items exist without proposals', () => {
    const badge = resolveLearnLoopNavBadge({
      planId: PLAN_ID,
      varianceSummary: varianceSummary({
        action_required_items: [
          {
            item_id: 1,
            field_cultivation_id: 42,
            category: 'general',
            name: 'Weed control',
            scheduled_date: '2026-06-01',
            actual_date: '2026-06-08',
            delta_days: 7,
            gdd_trigger: 100,
            gdd_at_actual: 110,
            gdd_delta: 10,
            exceedance_kind: 'days'
          }
        ]
      }),
      learningSnapshot: null
    });

    expect(badge).toEqual({ kind: 'phase', phaseId: 'observe' });
  });

  it('returns null when there is no learn activity', () => {
    expect(
      resolveLearnLoopNavBadge({
        planId: PLAN_ID,
        varianceSummary: varianceSummary(),
        learningSnapshot: null
      })
    ).toBeNull();
  });
});
