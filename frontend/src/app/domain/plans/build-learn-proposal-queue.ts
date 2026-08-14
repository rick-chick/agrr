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

export type LearnProposalQueueTier = 'safe' | 'needs_review' | 'action_required';

export type LearnProposalQueueItemKind = 'stage_gdd' | 'bp_timing' | 'variance_action';

export interface LearnProposalQueueItem {
  key: string;
  tier: LearnProposalQueueTier;
  kind: LearnProposalQueueItemKind;
  title: string;
}

export interface LearnProposalQueue {
  items: LearnProposalQueueItem[];
  tiers: Record<LearnProposalQueueTier, LearnProposalQueueItem[]>;
  totalCount: number;
}

const TIER_PRIORITY: LearnProposalQueueTier[] = ['action_required', 'needs_review', 'safe'];

function isQueueableStageGddProposal(
  planId: number,
  proposal: StageGddCalibrationProposal
): boolean {
  if (proposal.proposedRequiredGdd == null) {
    return false;
  }
  const status = resolveLearnProposalApplicationStatus(
    planId,
    stageGddProposalProgressKey(proposal.cropId, proposal.stageId)
  );
  return status === 'not_started';
}

function isQueueableBpTimingProposal(
  planId: number,
  proposal: BlueprintTimingAdjustmentProposal
): boolean {
  if ((proposal.proposalBody.task_schedule_blueprints?.length ?? 0) === 0) {
    return false;
  }
  const status = resolveLearnProposalApplicationStatus(
    planId,
    bpTimingProposalProgressKey(proposal.cropId, proposal.category)
  );
  return status === 'not_started';
}

function classifyProposalTier(
  planId: number,
  proposal: StageGddCalibrationProposal | BlueprintTimingAdjustmentProposal,
  kind: 'stage_gdd' | 'bp_timing'
): LearnProposalQueueTier {
  const isSafe =
    kind === 'stage_gdd'
      ? isSafeStageGddProposal(planId, proposal as StageGddCalibrationProposal)
      : isSafeBlueprintTimingProposal(planId, proposal as BlueprintTimingAdjustmentProposal);
  return isSafe ? 'safe' : 'needs_review';
}

export function buildLearnProposalQueue(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>,
  actionRequiredItems: ReadonlyArray<PlanVarianceActionItem>
): LearnProposalQueue {
  const items: LearnProposalQueueItem[] = [];

  for (const item of actionRequiredItems) {
    items.push({
      key: `variance_action:${item.item_id}`,
      tier: 'action_required',
      kind: 'variance_action',
      title: item.name
    });
  }

  for (const proposal of stageGddProposals) {
    if (!isQueueableStageGddProposal(planId, proposal)) {
      continue;
    }
    items.push({
      key: stageGddProposalProgressKey(proposal.cropId, proposal.stageId),
      tier: classifyProposalTier(planId, proposal, 'stage_gdd'),
      kind: 'stage_gdd',
      title: `${proposal.cropName} — ${proposal.stageName}`
    });
  }

  for (const proposal of blueprintTimingProposals) {
    if (!isQueueableBpTimingProposal(planId, proposal)) {
      continue;
    }
    items.push({
      key: bpTimingProposalProgressKey(proposal.cropId, proposal.category),
      tier: classifyProposalTier(planId, proposal, 'bp_timing'),
      kind: 'bp_timing',
      title: `${proposal.cropName} — ${proposal.category}`
    });
  }

  const sortByTier = (a: LearnProposalQueueItem, b: LearnProposalQueueItem): number =>
    TIER_PRIORITY.indexOf(a.tier) - TIER_PRIORITY.indexOf(b.tier);

  const sorted = [...items].sort(sortByTier);

  const tiers: Record<LearnProposalQueueTier, LearnProposalQueueItem[]> = {
    action_required: sorted.filter((item) => item.tier === 'action_required'),
    needs_review: sorted.filter((item) => item.tier === 'needs_review'),
    safe: sorted.filter((item) => item.tier === 'safe')
  };

  return {
    items: sorted,
    tiers,
    totalCount: sorted.length
  };
}
