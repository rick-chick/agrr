import { describe, expect, it, beforeEach } from 'vitest';
import type { BlueprintAmountAdjustmentProposal } from './blueprint-amount-adjustment-proposal';
import { BLUEPRINT_AMOUNT_PATCH_INTENT } from './blueprint-amount-adjustment-proposal';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import { BLUEPRINT_TIMING_PATCH_INTENT } from './blueprint-timing-adjustment-proposal';
import {
  buildFertilizerTimingQueueItems,
  buildPestControlTimingQueueItems,
  buildUnifiedLearnProposalQueue,
  groupUnifiedLearnProposalQueueByCategory,
  groupUnifiedLearnProposalQueueExcludingDedicatedTimingSections,
  isFertilizerBpTimingQueueItem,
  isPestControlBpTimingQueueItem,
  partitionFertilizerBpTimingQueueItems,
  partitionPestControlBpTimingQueueItems
} from './build-unified-learn-proposal-queue';
import {
  clearLearnProposalApplicationProgressCache,
  markBpTimingProposalAppliedPending
} from './learn-proposal-application-progress';
import { DAYS_VARIANCE_THRESHOLD, FERTILIZER_AMOUNT_DELTA_THRESHOLD, GDD_VARIANCE_THRESHOLD } from './plan-variance-thresholds';
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

const bpAmountProposal = (
  overrides: Partial<BlueprintAmountAdjustmentProposal> = {}
): BlueprintAmountAdjustmentProposal => ({
  cropId: 1,
  cropName: 'Tomato',
  category: 'fertilizer',
  taskType: 'fertilize',
  stageOrder: 1,
  stageName: 'Vegetative',
  averageAmountDelta: 0.4,
  recordedItemCount: 3,
  amountUnit: 'kg',
  affectedBlueprintCount: 1,
  proposalBody: {
    intent: BLUEPRINT_AMOUNT_PATCH_INTENT,
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: [{ blueprint_id: 10, amount: 2.5, amount_unit: 'kg' }]
  },
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

  it('categorizes bp_amount proposals as safe or requires_confirmation', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [],
      [],
      [
        bpAmountProposal({ averageAmountDelta: 0.4 }),
        bpAmountProposal({
          averageAmountDelta: FERTILIZER_AMOUNT_DELTA_THRESHOLD + 0.5,
          taskType: 'topdress',
          stageOrder: 2
        })
      ],
      []
    );

    expect(queue.counts.safe).toBe(1);
    expect(queue.counts.requires_confirmation).toBe(1);
    expect(queue.items.find((item) => item.kind === 'bp_amount' && item.category === 'safe')).toBeTruthy();
    expect(
      queue.items.find((item) => item.kind === 'bp_amount' && item.category === 'requires_confirmation')
    ).toBeTruthy();
  });

  it('assigns safe, requires_confirmation, and requires_action categories with counts', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [
        stageGddProposal({ stageId: 2, averageGddDelta: 5 }),
        stageGddProposal({ stageId: 3, averageGddDelta: GDD_VARIANCE_THRESHOLD + 5 })
      ],
      [bpTimingProposal({ category: 'general', averageDeltaDays: 2 })],
      [],
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
      [],
      [actionRequiredItem({ item_id: 1, name: 'Task A' })]
    );

    expect(queue.items[0].category).toBe('requires_action');
    expect(queue.items[1].category).toBe('requires_confirmation');
    expect(queue.items[2].category).toBe('safe');
  });

  it('returns empty queue when no proposals or action items exist', () => {
    const queue = buildUnifiedLearnProposalQueue(planId, [], [], [], []);

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
      [],
      [actionRequiredItem()]
    );
    const grouped = groupUnifiedLearnProposalQueueByCategory(queue);

    expect(grouped.requires_action).toHaveLength(1);
    expect(grouped.requires_confirmation).toHaveLength(0);
    expect(grouped.safe).toHaveLength(1);
  });

  it('tags fertilizer bp_timing items with bpTimingCategory for dedicated section', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [],
      [
        bpTimingProposal({ category: 'fertilizer', averageDeltaDays: 2 }),
        bpTimingProposal({ category: 'general', averageDeltaDays: 2 })
      ],
      [],
      []
    );

    const fertilizerItem = queue.items.find((item) => item.id.includes('fertilizer'));
    const generalItem = queue.items.find((item) => item.id.includes('general'));

    expect(fertilizerItem?.bpTimingCategory).toBe('fertilizer');
    expect(isFertilizerBpTimingQueueItem(fertilizerItem!)).toBe(true);
    expect(generalItem?.bpTimingCategory).toBe('general');
    expect(isFertilizerBpTimingQueueItem(generalItem!)).toBe(false);
  });

  it('partitions fertilizer bp_timing items for dedicated queue section', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [stageGddProposal({ averageGddDelta: 5 })],
      [
        bpTimingProposal({ category: 'fertilizer', averageDeltaDays: 2 }),
        bpTimingProposal({ category: 'general', averageDeltaDays: 2 })
      ],
      [],
      []
    );

    const { fertilizerTiming, other } = partitionFertilizerBpTimingQueueItems(queue.items);

    expect(fertilizerTiming).toHaveLength(1);
    expect(fertilizerTiming[0].bpTimingCategory).toBe('fertilizer');
    expect(other).toHaveLength(2);
    expect(other.map((item) => item.kind)).toEqual(['stage_gdd', 'bp_timing']);
  });

  it('excludes fertilizer bp_timing from category grouping', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [],
      [
        bpTimingProposal({ category: 'fertilizer', averageDeltaDays: 2 }),
        bpTimingProposal({ category: 'general', averageDeltaDays: 2 })
      ],
      [],
      []
    );
    const grouped = groupUnifiedLearnProposalQueueExcludingDedicatedTimingSections(queue);

    expect(grouped.safe).toHaveLength(1);
    expect(grouped.safe[0].bpTimingCategory).toBe('general');
  });

  it('builds fertilizer timing queue items including applied proposals for status display', () => {
    markBpTimingProposalAppliedPending(planId, { cropId: 1, category: 'fertilizer' });
    const items = buildFertilizerTimingQueueItems(planId, [
      bpTimingProposal({ category: 'fertilizer', averageDeltaDays: 2 })
    ]);

    expect(items).toHaveLength(1);
    expect(items[0].title).toBe('Tomato');
    expect(items[0].bpTimingCategory).toBe('fertilizer');
  });

  it('tags pest_control bp_timing items with bpTimingCategory for dedicated section', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [],
      [
        bpTimingProposal({ category: 'pest_control', averageDeltaDays: 2 }),
        bpTimingProposal({ category: 'general', averageDeltaDays: 2 })
      ],
      [],
      []
    );

    const pestControlItem = queue.items.find((item) => item.id.includes('pest_control'));
    const generalItem = queue.items.find((item) => item.id.includes('general'));

    expect(pestControlItem?.bpTimingCategory).toBe('pest_control');
    expect(isPestControlBpTimingQueueItem(pestControlItem!)).toBe(true);
    expect(generalItem?.bpTimingCategory).toBe('general');
    expect(isPestControlBpTimingQueueItem(generalItem!)).toBe(false);
  });

  it('partitions pest_control bp_timing items for dedicated queue section', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [stageGddProposal({ averageGddDelta: 5 })],
      [
        bpTimingProposal({ category: 'pest_control', averageDeltaDays: 2 }),
        bpTimingProposal({ category: 'general', averageDeltaDays: 2 })
      ],
      [],
      []
    );

    const { pestControlTiming, other } = partitionPestControlBpTimingQueueItems(queue.items);

    expect(pestControlTiming).toHaveLength(1);
    expect(pestControlTiming[0].bpTimingCategory).toBe('pest_control');
    expect(other).toHaveLength(2);
    expect(other.map((item) => item.kind)).toEqual(['stage_gdd', 'bp_timing']);
  });

  it('excludes fertilizer and pest_control bp_timing from category grouping', () => {
    const queue = buildUnifiedLearnProposalQueue(
      planId,
      [],
      [
        bpTimingProposal({ category: 'fertilizer', averageDeltaDays: 2 }),
        bpTimingProposal({ category: 'pest_control', averageDeltaDays: 2 }),
        bpTimingProposal({ category: 'general', averageDeltaDays: 2 })
      ],
      [],
      []
    );
    const grouped = groupUnifiedLearnProposalQueueExcludingDedicatedTimingSections(queue);

    expect(grouped.safe).toHaveLength(1);
    expect(grouped.safe[0].bpTimingCategory).toBe('general');
  });

  it('builds pest control timing queue items including applied proposals for status display', () => {
    markBpTimingProposalAppliedPending(planId, { cropId: 1, category: 'pest_control' });
    const items = buildPestControlTimingQueueItems(planId, [
      bpTimingProposal({ category: 'pest_control', averageDeltaDays: 2 })
    ]);

    expect(items).toHaveLength(1);
    expect(items[0].title).toBe('Tomato');
    expect(items[0].bpTimingCategory).toBe('pest_control');
  });
});
