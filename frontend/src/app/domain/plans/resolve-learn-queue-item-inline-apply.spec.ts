import { describe, expect, it } from 'vitest';
import { BLUEPRINT_TIMING_PATCH_INTENT } from './blueprint-timing-adjustment-proposal';
import type { UnifiedLearnProposalQueueItem } from './build-unified-learn-proposal-queue';
import {
  findBpTimingProposalForQueueItem,
  findStageGddProposalForQueueItem,
  resolveLearnQueueItemInlineApplyMode
} from './resolve-learn-queue-item-inline-apply';

const stageGddItem = (
  overrides: Partial<UnifiedLearnProposalQueueItem> = {}
): UnifiedLearnProposalQueueItem => ({
  id: 'stage_gdd:1:2',
  kind: 'stage_gdd',
  category: 'requires_confirmation',
  priority: 0,
  title: 'Tomato — Vegetative',
  ...overrides
});

const bpTimingItem = (
  overrides: Partial<UnifiedLearnProposalQueueItem> = {}
): UnifiedLearnProposalQueueItem => ({
  id: 'bp_timing:1:general',
  kind: 'bp_timing',
  category: 'requires_confirmation',
  priority: 0,
  title: 'Tomato',
  subtitle: 'general',
  bpTimingCategory: 'general',
  ...overrides
});

describe('resolve-learn-queue-item-inline-apply', () => {
  it('returns stage_gdd mode when proposedRequiredGdd is present', () => {
    expect(
      resolveLearnQueueItemInlineApplyMode(
        stageGddItem(),
        [
          {
            cropId: 1,
            cropName: 'Tomato',
            stageId: 2,
            stageOrder: 1,
            stageName: 'Vegetative',
            averageGddDelta: 50,
            recordedItemCount: 2,
            currentRequiredGdd: 100,
            proposedRequiredGdd: 150
          }
        ],
        []
      )
    ).toBe('stage_gdd');
  });

  it('returns detail_edit_only when stage gdd proposal lacks proposedRequiredGdd', () => {
    expect(
      resolveLearnQueueItemInlineApplyMode(
        stageGddItem(),
        [
          {
            cropId: 1,
            cropName: 'Tomato',
            stageId: 2,
            stageOrder: 1,
            stageName: 'Vegetative',
            averageGddDelta: 50,
            recordedItemCount: 2,
            currentRequiredGdd: 100,
            proposedRequiredGdd: null
          }
        ],
        []
      )
    ).toBe('detail_edit_only');
  });

  it('returns bp_timing mode when blueprint patches exist', () => {
    expect(
      resolveLearnQueueItemInlineApplyMode(
        bpTimingItem(),
        [],
        [
          {
            cropId: 1,
            cropName: 'Tomato',
            category: 'general',
            averageDeltaDays: 5,
            averageGddDelta: 10,
            recordedItemCount: 2,
            affectedBlueprintCount: 1,
            proposalBody: {
              intent: BLUEPRINT_TIMING_PATCH_INTENT,
              stages: [],
              agricultural_tasks: [],
              task_schedule_blueprints: [{ blueprint_id: 1, gdd_trigger: 100 }]
            }
          }
        ]
      )
    ).toBe('bp_timing');
  });

  it('returns detail_edit_only when bp timing proposal has no blueprint patches', () => {
    expect(
      resolveLearnQueueItemInlineApplyMode(
        bpTimingItem(),
        [],
        [
          {
            cropId: 1,
            cropName: 'Tomato',
            category: 'general',
            averageDeltaDays: 5,
            averageGddDelta: 10,
            recordedItemCount: 2,
            affectedBlueprintCount: 0,
            proposalBody: {
              intent: BLUEPRINT_TIMING_PATCH_INTENT,
              stages: [],
              agricultural_tasks: [],
              task_schedule_blueprints: []
            }
          }
        ]
      )
    ).toBe('detail_edit_only');
  });

  it('returns null for safe or requires_action categories', () => {
    expect(
      resolveLearnQueueItemInlineApplyMode(
        stageGddItem({ category: 'safe' }),
        [],
        []
      )
    ).toBeNull();
    expect(
      resolveLearnQueueItemInlineApplyMode(
        {
          id: 'action_required:1',
          kind: 'action_required',
          category: 'requires_action',
          priority: 0,
          title: 'Weed control'
        },
        [],
        []
      )
    ).toBeNull();
  });

  it('finds proposals by queue item id', () => {
    const stageProposal = {
      cropId: 1,
      cropName: 'Tomato',
      stageId: 2,
      stageOrder: 1,
      stageName: 'Vegetative',
      averageGddDelta: 50,
      recordedItemCount: 2,
      currentRequiredGdd: 100,
      proposedRequiredGdd: 150
    };
    const bpProposal = {
      cropId: 1,
      cropName: 'Tomato',
      category: 'general',
      averageDeltaDays: 5,
      averageGddDelta: 10,
      recordedItemCount: 2,
      affectedBlueprintCount: 1,
      proposalBody: {
        intent: BLUEPRINT_TIMING_PATCH_INTENT,
        stages: [],
        agricultural_tasks: [],
        task_schedule_blueprints: [{ blueprint_id: 1, gdd_trigger: 100 }]
      }
    };

    expect(findStageGddProposalForQueueItem(stageGddItem(), [stageProposal])).toEqual(stageProposal);
    expect(findBpTimingProposalForQueueItem(bpTimingItem(), [bpProposal])).toEqual(bpProposal);
  });
});
