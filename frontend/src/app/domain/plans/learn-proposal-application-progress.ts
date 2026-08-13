import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

export type LearnProposalKind = 'stage_gdd' | 'bp_timing';

export type LearnProposalApplicationStatus = 'not_started' | 'applied_pending_confirmation';

export interface LearnProposalProgressItem {
  kind: LearnProposalKind;
  key: string;
  cropName: string;
  detailLabel: string;
  status: LearnProposalApplicationStatus;
}

export function stageGddProposalKey(cropId: number, stageId: number): string {
  return `stage_gdd:${cropId}:${stageId}`;
}

export function bpTimingProposalKey(cropId: number, category: string): string {
  return `bp_timing:${cropId}:${category}`;
}

export function learnAppliedProposalStorageKey(planId: number): string {
  return `agrr:learn-applied-proposals:${planId}`;
}

export function readAppliedProposalKeys(
  planId: number,
  storage: Storage | null = sessionStorage
): Set<string> {
  if (!storage) {
    return new Set();
  }
  const raw = storage.getItem(learnAppliedProposalStorageKey(planId));
  if (!raw) {
    return new Set();
  }
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      return new Set();
    }
    return new Set(parsed.filter((entry): entry is string => typeof entry === 'string'));
  } catch {
    return new Set();
  }
}

export function writeAppliedProposalKeys(
  planId: number,
  keys: ReadonlySet<string>,
  storage: Storage | null = sessionStorage
): void {
  if (!storage) {
    return;
  }
  storage.setItem(
    learnAppliedProposalStorageKey(planId),
    JSON.stringify([...keys])
  );
}

export function markProposalApplied(
  planId: number,
  key: string,
  storage: Storage | null = sessionStorage
): void {
  const keys = readAppliedProposalKeys(planId, storage);
  keys.add(key);
  writeAppliedProposalKeys(planId, keys, storage);
}

export function buildLearnProposalProgressItems(
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  bpTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>,
  appliedKeys: ReadonlySet<string>
): LearnProposalProgressItem[] {
  const items: LearnProposalProgressItem[] = [];

  for (const proposal of stageGddProposals) {
    const key = stageGddProposalKey(proposal.cropId, proposal.stageId);
    items.push({
      kind: 'stage_gdd',
      key,
      cropName: proposal.cropName,
      detailLabel: proposal.stageName,
      status: appliedKeys.has(key) ? 'applied_pending_confirmation' : 'not_started'
    });
  }

  for (const proposal of bpTimingProposals) {
    const key = bpTimingProposalKey(proposal.cropId, proposal.category);
    items.push({
      kind: 'bp_timing',
      key,
      cropName: proposal.cropName,
      detailLabel: proposal.category,
      status: appliedKeys.has(key) ? 'applied_pending_confirmation' : 'not_started'
    });
  }

  return items;
}
