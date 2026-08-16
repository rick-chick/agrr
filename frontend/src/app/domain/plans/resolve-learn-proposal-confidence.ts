import type { BlueprintAmountAdjustmentProposal } from './blueprint-amount-adjustment-proposal';
import type { LearnProposalEvidence } from './learn-proposal-evidence';
import type { LearnProposalEvidenceSource } from './learn-proposal-evidence';
import { amountDeltaThresholdForCategory } from './plan-variance-thresholds';

export type LearnProposalConfidence = 'high' | 'medium' | 'low';

const MIN_STAGE_RECORDED_COUNT_FOR_MEDIUM = 2;
const MIN_STAGE_RECORDED_COUNT_FOR_HIGH = 3;

export function resolveLearnProposalConfidence(input: {
  unrecordedCount: number;
  actionRequiredCount: number;
}): LearnProposalConfidence {
  if (input.unrecordedCount > 0) {
    return 'low';
  }
  if (input.actionRequiredCount > 0) {
    return 'medium';
  }
  return 'high';
}

export interface BpAmountProposalConfidenceInput {
  planUnrecordedCount: number;
  planActionRequiredCount: number;
  proposal: Pick<
    BlueprintAmountAdjustmentProposal,
    'category' | 'recordedItemCount' | 'averageAmountDelta' | 'amountUnit'
  >;
  evidence?: LearnProposalEvidence | null;
  hasUnitMismatch?: boolean;
}

function normalizeAmountUnit(unit: string | null | undefined): string | null {
  const trimmed = unit?.trim();
  return trimmed ? trimmed.toLowerCase() : null;
}

function countsTowardUnitMismatch(source: LearnProposalEvidenceSource): boolean {
  return source.status !== 'skipped';
}

function matchesBpAmountProposal(
  proposal: Pick<
    BlueprintAmountAdjustmentProposal,
    'cropId' | 'category' | 'taskType' | 'stageOrder'
  >,
  source: LearnProposalEvidenceSource
): boolean {
  return (
    countsTowardUnitMismatch(source) &&
    source.cropId === proposal.cropId &&
    source.category === proposal.category &&
    (source.taskType == null || source.taskType === proposal.taskType) &&
    source.stageOrder === proposal.stageOrder
  );
}

export function detectBpAmountProposalUnitMismatch(
  proposal: Pick<
    BlueprintAmountAdjustmentProposal,
    'cropId' | 'category' | 'taskType' | 'stageOrder' | 'amountUnit'
  >,
  sources: ReadonlyArray<LearnProposalEvidenceSource>
): boolean {
  const proposalUnit = normalizeAmountUnit(proposal.amountUnit);
  if (!proposalUnit) {
    return false;
  }

  const matchingUnits = sources
    .filter((source) => matchesBpAmountProposal(proposal, source))
    .map((source) => normalizeAmountUnit(source.amountUnit))
    .filter((unit): unit is string => unit != null);

  if (matchingUnits.length === 0) {
    return false;
  }

  return matchingUnits.some((unit) => unit !== proposalUnit);
}

export function resolveBpAmountProposalConfidence(
  input: BpAmountProposalConfidenceInput
): LearnProposalConfidence {
  if (input.planUnrecordedCount > 0) {
    return 'low';
  }

  if (input.hasUnitMismatch) {
    return 'low';
  }

  const recordedCount = input.proposal.recordedItemCount;
  if (recordedCount < MIN_STAGE_RECORDED_COUNT_FOR_MEDIUM) {
    return 'low';
  }

  if (input.planActionRequiredCount > 0) {
    return 'medium';
  }

  const threshold = amountDeltaThresholdForCategory(input.proposal.category);
  const strongVariance = Math.abs(input.proposal.averageAmountDelta) >= threshold * 2;
  const hasExceedance = (input.evidence?.exceedanceCount ?? 0) > 0;

  if (
    recordedCount >= MIN_STAGE_RECORDED_COUNT_FOR_HIGH &&
    (strongVariance || hasExceedance)
  ) {
    return 'high';
  }

  return 'medium';
}
