import { describe, expect, it, beforeEach } from 'vitest';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import { BLUEPRINT_TIMING_PATCH_INTENT } from './blueprint-timing-adjustment-proposal';
import {
  buildUnifiedLearnProposalQueue,
  groupUnifiedLearnProposalQueueByCategory
} from './build-unified-learn-proposal-queue';
import { clearLearnProposalApplicationProgressCache } from './learn-proposal-application-progress';
import { DAYS_VARIANCE_THRESHOLD, GDD_VARIANCE_THRESHOLD } from './plan-variance-thresholds';
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

const actionRequiredItem = (
  overrides: Partial<PlanVarianceActionItem> = {}
): PlanVarianceActionItem => ({
  item_id: 11,
  field_cultivation_id: 100,
  category: 'general',
  name: 'Weed control',
  scheduled_date: '2026-06-01',
  actual_date: '2026-06-08',
  delta_days: 7,
  gdd_trigger: 100,
  gdd_at_actual: 110,
  gdd_delta: 10,
  exceedance_kind: 'days',
  ...overrides
});

describe('build-unified-learn-proposal-queue', () => {
  const planId = 7;

  beforeEach(() => {
    clearLearnProposalApplicationProgressCache();
  });

  it('assigns safe, requires_confirmation, and requires_action categories with counts', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [
        stageGddProposal({ stageId: 2, averageGddDelta: 5 }),
        stageGddProposal({ stageId: 3, averageGddDelta: GDD_VARIANCE_THRESHOLD + 5 })
      ],
      [bpTimingProposal({ category: 'general', averageDeltaDays: 2 })],
      [actionRequiredItem()]
    );

    expect(queue.counts).toEqual({
      requires_action: 1,
      requires_confirmation: 1,
      safe: 2
    });
    expect(queue.items.map((item) => item.category)).toEqual([
      'requires_action',
      'requires_confirmation',
      'safe',
      'safe'
    ]);
  });

  it('orders requires_action before requires_confirmation before safe', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [stageGddProposal({ averageGddDelta: 5 })],
      [bpTimingProposal({ averageDeltaDays: DAYS_VARIANCE_THRESHOLD + 2 })],
      [actionRequiredItem({ item_id: 1, name: 'Task A' })]
    );

    expect(queue.items[0].category).toBe('requires_action');
    expect(queue.items[1].category).toBe('requires_confirmation');
    expect(queue.items[2].category).toBe('safe');
  });

  it('returns empty queue when no proposals or action items exist', () => {
    const queue = buildUnifiedLearnProposalQueue(planId, [], [], []);

    expect(queue.items).toEqual([]);
    expect(queue.counts).toEqual({
      requires_action: 0,
      requires_confirmation: 0,
      safe: 0
    });
  });

  it('groups items by category for UI sections', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [stageGddProposal({ averageGddDelta: 5 })],
      [],
      [actionRequiredItem()]
    );
    const grouped = groupUnifiedLearnProposalQueueByCategory(queue);

    expect(grouped.requires_action).toHaveLength(1);
    expect(grouped.requires_confirmation).toHaveLength(0);
    expect(grouped.safe).toHaveLength(1);
  });
});
