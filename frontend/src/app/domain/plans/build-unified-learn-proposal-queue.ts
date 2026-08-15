import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  isSafeBlueprintTimingProposal,
  isSafeStageGddProposal
} from './classify-safe-learn-proposals';
import {
  bpTimingProposalProgressKey,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from './learn-proposal-application-progress';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

export type LearnProposalQueueCategory = 'safe' | 'requires_confirmation' | 'requires_action';

export type LearnProposalQueueItemKind = 'stage_gdd' | 'bp_timing' | 'action_required';

export interface UnifiedLearnProposalQueueItem {
  id: string;
  kind: LearnProposalQueueItemKind;
  category: LearnProposalQueueCategory;
  priority: number;
  title: string;
  subtitle?: string;
  bpTimingCategory?: string;
}

export interface UnifiedLearnProposalQueue {
  items: UnifiedLearnProposalQueueItem[];
  counts: Record<LearnProposalQueueCategory, number>;
}

const CATEGORY_PRIORITY: Record<LearnProposalQueueCategory, number> = {
  requires_action: 0,
  requires_confirmation: 1,
  safe: 2
};

function isRequiresConfirmationStageGdd(
  planId: number,
  proposal: StageGddCalibrationProposal
): boolean {
  const key = stageGddProposalProgressKey(proposal.cropId, proposal.stageId);
  if (resolveLearnProposalApplicationStatus(planId, key) !== 'not_started') {
    return false;
  }
  return !isSafeStageGddProposal(planId, proposal);
}

function isRequiresConfirmationBpTiming(
  planId: number,
  proposal: BlueprintTimingAdjustmentProposal
): boolean {
  const key = bpTimingProposalProgressKey(proposal.cropId, proposal.category);
  if (resolveLearnProposalApplicationStatus(planId, key) !== 'not_started') {
    return false;
  }
  return !isSafeBlueprintTimingProposal(planId, proposal);
}

function magnitudePriority(value: number): number {
  return -Math.abs(value);
}

export function buildUnifiedLearnProposalQueue(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>,
  actionRequiredItems: ReadonlyArray<PlanVarianceActionItem> = []
): UnifiedLearnProposalQueue {
  const items: UnifiedLearnProposalQueueItem[] = [];

  for (const item of actionRequiredItems) {
    items.push({
      id: `action_required:${item.item_id}`,
      kind: 'action_required',
      category: 'requires_action',
      priority: CATEGORY_PRIORITY.requires_action * 1000 + magnitudePriority(item.delta_days ?? 0),
      title: item.name,
      subtitle: item.category
    });
  }

  for (const proposal of stageGddProposals) {
    if (isSafeStageGddProposal(planId, proposal)) {
      items.push({
        id: `stage_gdd:${proposal.cropId}:${proposal.stageId}`,
        kind: 'stage_gdd',
        category: 'safe',
        priority: CATEGORY_PRIORITY.safe * 1000 + magnitudePriority(proposal.averageGddDelta),
        title: `${proposal.cropName} — ${proposal.stageName}`
      });
    } else if (isRequiresConfirmationStageGdd(planId, proposal)) {
      items.push({
        id: `stage_gdd:${proposal.cropId}:${proposal.stageId}`,
        kind: 'stage_gdd',
        category: 'requires_confirmation',
        priority:
          CATEGORY_PRIORITY.requires_confirmation * 1000 +
          magnitudePriority(proposal.averageGddDelta),
        title: `${proposal.cropName} — ${proposal.stageName}`
      });
    }
  }

  for (const proposal of blueprintTimingProposals) {
    if (isSafeBlueprintTimingProposal(planId, proposal)) {
      items.push({
        id: `bp_timing:${proposal.cropId}:${proposal.category}`,
        kind: 'bp_timing',
        category: 'safe',
        priority: CATEGORY_PRIORITY.safe * 1000 + magnitudePriority(proposal.averageDeltaDays),
        title: proposal.cropName,
        subtitle: proposal.category,
        bpTimingCategory: proposal.category
      });
    } else if (isRequiresConfirmationBpTiming(planId, proposal)) {
      items.push({
        id: `bp_timing:${proposal.cropId}:${proposal.category}`,
        kind: 'bp_timing',
        category: 'requires_confirmation',
        priority:
          CATEGORY_PRIORITY.requires_confirmation * 1000 +
          magnitudePriority(proposal.averageDeltaDays),
        title: proposal.cropName,
        subtitle: proposal.category,
        bpTimingCategory: proposal.category
      });
    }
  }

  items.sort((a, b) => a.priority - b.priority);

  const counts: Record<LearnProposalQueueCategory, number> = {
    requires_action: 0,
    requires_confirmation: 0,
    safe: 0
  };
  for (const item of items) {
    counts[item.category] += 1;
  }

  return { items, counts };
}

export function groupUnifiedLearnProposalQueueByCategory(
  queue: UnifiedLearnProposalQueue
): Record<LearnProposalQueueCategory, UnifiedLearnProposalQueueItem[]> {
  return {
    requires_action: queue.items.filter((item) => item.category === 'requires_action'),
    requires_confirmation: queue.items.filter((item) => item.category === 'requires_confirmation'),
    safe: queue.items.filter((item) => item.category === 'safe')
  };
}

export const FERTILIZER_BP_TIMING_CATEGORY = 'fertilizer';
export const PEST_CONTROL_BP_TIMING_CATEGORY = 'pest_control';

export function isFertilizerBpTimingQueueItem(item: UnifiedLearnProposalQueueItem): boolean {
  return item.kind === 'bp_timing' && item.bpTimingCategory === FERTILIZER_BP_TIMING_CATEGORY;
}

export function isPestControlBpTimingQueueItem(item: UnifiedLearnProposalQueueItem): boolean {
  return item.kind === 'bp_timing' && item.bpTimingCategory === PEST_CONTROL_BP_TIMING_CATEGORY;
}

export function partitionFertilizerBpTimingQueueItems(
  items: ReadonlyArray<UnifiedLearnProposalQueueItem>
): {
  fertilizerTiming: UnifiedLearnProposalQueueItem[];
  other: UnifiedLearnProposalQueueItem[];
} {
  const fertilizerTiming: UnifiedLearnProposalQueueItem[] = [];
  const other: UnifiedLearnProposalQueueItem[] = [];

  for (const item of items) {
    if (isFertilizerBpTimingQueueItem(item)) {
      fertilizerTiming.push(item);
    } else {
      other.push(item);
    }
  }

  return { fertilizerTiming, other };
}

export function partitionPestControlBpTimingQueueItems(
  items: ReadonlyArray<UnifiedLearnProposalQueueItem>
): {
  pestControlTiming: UnifiedLearnProposalQueueItem[];
  other: UnifiedLearnProposalQueueItem[];
} {
  const pestControlTiming: UnifiedLearnProposalQueueItem[] = [];
  const other: UnifiedLearnProposalQueueItem[] = [];

  for (const item of items) {
    if (isPestControlBpTimingQueueItem(item)) {
      pestControlTiming.push(item);
    } else {
      other.push(item);
    }
  }

  return { pestControlTiming, other };
}

function countByCategory(
  items: ReadonlyArray<UnifiedLearnProposalQueueItem>
): Record<LearnProposalQueueCategory, number> {
  const counts: Record<LearnProposalQueueCategory, number> = {
    requires_action: 0,
    requires_confirmation: 0,
    safe: 0
  };
  for (const item of items) {
    counts[item.category] += 1;
  }
  return counts;
}

export function groupUnifiedLearnProposalQueueExcludingDedicatedTimingSections(
  queue: UnifiedLearnProposalQueue
): Record<LearnProposalQueueCategory, UnifiedLearnProposalQueueItem[]> {
  const { other: withoutFertilizer } = partitionFertilizerBpTimingQueueItems(queue.items);
  const { other } = partitionPestControlBpTimingQueueItems(withoutFertilizer);
  return groupUnifiedLearnProposalQueueByCategory({ items: other, counts: countByCategory(other) });
}

/** @deprecated Use groupUnifiedLearnProposalQueueExcludingDedicatedTimingSections */
export function groupUnifiedLearnProposalQueueExcludingFertilizerTiming(
  queue: UnifiedLearnProposalQueue
): Record<LearnProposalQueueCategory, UnifiedLearnProposalQueueItem[]> {
  return groupUnifiedLearnProposalQueueExcludingDedicatedTimingSections(queue);
}

export function buildFertilizerTimingQueueItems(
  planId: number,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): UnifiedLearnProposalQueueItem[] {
  return blueprintTimingProposals
    .filter((proposal) => proposal.category === FERTILIZER_BP_TIMING_CATEGORY)
    .filter((proposal) => {
      const status = resolveLearnProposalApplicationStatus(
        planId,
        bpTimingProposalProgressKey(proposal.cropId, proposal.category)
      );
      return status !== 'dismissed';
    })
    .map((proposal) => {
      const status = resolveLearnProposalApplicationStatus(
        planId,
        bpTimingProposalProgressKey(proposal.cropId, proposal.category)
      );
      const category: LearnProposalQueueCategory = isSafeBlueprintTimingProposal(planId, proposal)
        ? 'safe'
        : status === 'not_started'
          ? 'requires_confirmation'
          : 'safe';
      return {
        id: `bp_timing:${proposal.cropId}:${proposal.category}`,
        kind: 'bp_timing' as const,
        category,
        priority: 0,
        title: proposal.cropName,
        subtitle: proposal.category,
        bpTimingCategory: proposal.category
      };
    });
}

export function buildPestControlTimingQueueItems(
  planId: number,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): UnifiedLearnProposalQueueItem[] {
  return blueprintTimingProposals
    .filter((proposal) => proposal.category === PEST_CONTROL_BP_TIMING_CATEGORY)
    .filter((proposal) => {
      const status = resolveLearnProposalApplicationStatus(
        planId,
        bpTimingProposalProgressKey(proposal.cropId, proposal.category)
      );
      return status !== 'dismissed';
    })
    .map((proposal) => {
      const status = resolveLearnProposalApplicationStatus(
        planId,
        bpTimingProposalProgressKey(proposal.cropId, proposal.category)
      );
      const category: LearnProposalQueueCategory = isSafeBlueprintTimingProposal(planId, proposal)
        ? 'safe'
        : status === 'not_started'
          ? 'requires_confirmation'
          : 'safe';
      return {
        id: `bp_timing:${proposal.cropId}:${proposal.category}`,
        kind: 'bp_timing' as const,
        category,
        priority: 0,
        title: proposal.cropName,
        subtitle: proposal.category,
        bpTimingCategory: proposal.category
      };
    });
}

export function resolveBpTimingEvidenceKey(proposal: BlueprintTimingAdjustmentProposal): string {
  return `${proposal.cropId}-${proposal.category}`;
}
