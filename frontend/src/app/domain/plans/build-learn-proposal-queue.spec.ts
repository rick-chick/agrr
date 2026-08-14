import { describe, expect, it, beforeEach } from 'vitest';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import { BLUEPRINT_TIMING_PATCH_INTENT } from './blueprint-timing-adjustment-proposal';
import {
  buildLearnProposalQueue,
  type LearnProposalQueueTier
} from './build-learn-proposal-queue';
import { clearLearnProposalApplicationProgressCache } from './learn-proposal-application-progress';
import { GDD_VARIANCE_THRESHOLD } from './plan-variance-thresholds';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

const stageGddProposal = (
  overrides: Partial<StageGddCalibrationProposal> = {}
): StageGddCalibrationProposal => ({
  cropId: 1,
  cropName: 'Tomato',
  stageId: 2,
  stageOrder: 1,
  stageName: 'Vegetative',
  averageGddDelta: 5,
  recordedItemCount: 3,
  currentRequiredGdd: 100,
  proposedRequiredGdd: 105,
  ...overrides
});

const bpTimingProposal = (
  overrides: Partial<BlueprintTimingAdjustmentProposal> = {}
): BlueprintTimingAdjustmentProposal => ({
  cropId: 1,
  cropName: 'Tomato',
  category: 'general',
  averageDeltaDays: 2,
  averageGddDelta: 5,
  recordedItemCount: 4,
  affectedBlueprintCount: 2,
  proposalBody: {
    intent: BLUEPRINT_TIMING_PATCH_INTENT,
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: [{ blueprint_id: 10, gdd_trigger: 120 }]
  },
  ...overrides
});

const actionItem = (overrides: Partial<PlanVarianceActionItem> = {}): PlanVarianceActionItem => ({
  item_id: 100,
  field_cultivation_id: 200,
  category: 'general',
  name: 'Transplant',
  scheduled_date: '2026-03-01',
  actual_date: '2026-03-10',
  delta_days: 9,
  gdd_trigger: 120,
  gdd_at_actual: 130,
  gdd_delta: 10,
  exceedance_kind: 'days',
  ...overrides
});

describe('buildLearnProposalQueue', () => {
  const planId = 7;

  beforeEach(() => {
    clearLearnProposalApplicationProgressCache();
  });

  it('classifies safe proposals into the safe tier', () => {
    const queue = buildLearnProposalQueue(
      planId,
      [stageGddProposal({ averageGddDelta: 5 })],
      [bpTimingProposal({ averageDeltaDays: 2 })],
      []
    );

    expect(queue.tiers.safe).toHaveLength(2);
    expect(queue.tiers.needs_review).toHaveLength(0);
    expect(queue.tiers.action_required).toHaveLength(0);
    expect(queue.items.every((item) => item.tier === 'safe')).toBe(true);
  });

  it('classifies non-safe not-started proposals into needs_review tier', () => {
    const queue = buildLearnProposalQueue(
      planId,
      [stageGddProposal({ averageGddDelta: GDD_VARIANCE_THRESHOLD + 5 })],
      [bpTimingProposal({ averageDeltaDays: 20 })],
      []
    );

    expect(queue.tiers.safe).toHaveLength(0);
    expect(queue.tiers.needs_review).toHaveLength(2);
    expect(queue.tiers.action_required).toHaveLength(0);
  });

  it('includes variance action items in action_required tier', () => {
    const queue = buildLearnProposalQueue(planId, [], [], [actionItem()]);

    expect(queue.tiers.action_required).toHaveLength(1);
    expect(queue.tiers.action_required[0].title).toBe('Transplant');
    expect(queue.tiers.action_required[0].kind).toBe('variance_action');
  });

  it('orders items action_required → needs_review → safe', () => {
    const queue = buildLearnProposalQueue(
      planId,
      [stageGddProposal({ stageId: 2, averageGddDelta: 5 })],
      [bpTimingProposal({ category: 'fertilizer', averageDeltaDays: 20 })],
      [actionItem()]
    );

    const tierOrder: LearnProposalQueueTier[] = queue.items.map((item) => item.tier);
    expect(tierOrder).toEqual(['action_required', 'needs_review', 'safe']);
  });

  it('excludes already addressed proposals from the queue', () => {
    const queue = buildLearnProposalQueue(
      planId,
      [stageGddProposal({ proposedRequiredGdd: null })],
      [
        bpTimingProposal({
          proposalBody: {
            intent: BLUEPRINT_TIMING_PATCH_INTENT,
            stages: [],
            agricultural_tasks: [],
            task_schedule_blueprints: []
          }
        })
      ],
      []
    );

    expect(queue.totalCount).toBe(0);
  });
});
