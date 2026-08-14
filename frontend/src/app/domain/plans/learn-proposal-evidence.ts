import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  DAYS_VARIANCE_THRESHOLD,
  GDD_VARIANCE_THRESHOLD
} from './plan-variance-thresholds';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

export interface LearnProposalContributingRecord {
  name: string;
  actualDate: string | null;
}

export interface LearnProposalEvidence {
  exceedanceCount: number;
  thresholdValue: number;
  contributingRecords: LearnProposalContributingRecord[];
  totalRecordedCount: number;
}

export interface LearnProposalEvidenceSource {
  cropId: number;
  category: string;
  stageOrder: number | null;
  name: string;
  actualDate: string | null;
  deltaDays: number | null;
  gddDelta: number | null;
  status: string;
}

const MAX_CONTRIBUTING_RECORDS = 5;

function countsTowardEvidence(source: LearnProposalEvidenceSource): boolean {
  return source.status !== 'skipped';
}

function sortByAbsDesc(values: ReadonlyArray<LearnProposalEvidenceSource>, pick: (row: LearnProposalEvidenceSource) => number | null): LearnProposalEvidenceSource[] {
  return [...values].sort((left, right) => {
    const leftAbs = Math.abs(pick(left) ?? 0);
    const rightAbs = Math.abs(pick(right) ?? 0);
    return rightAbs - leftAbs;
  });
}

function toContributingRecords(
  sources: ReadonlyArray<LearnProposalEvidenceSource>
): LearnProposalContributingRecord[] {
  return sources.slice(0, MAX_CONTRIBUTING_RECORDS).map((source) => ({
    name: source.name,
    actualDate: source.actualDate
  }));
}

export function buildStageGddProposalEvidence(
  proposal: StageGddCalibrationProposal,
  sources: ReadonlyArray<LearnProposalEvidenceSource>
): LearnProposalEvidence | null {
  const matching = sources.filter(
    (source) =>
      countsTowardEvidence(source) &&
      source.cropId === proposal.cropId &&
      source.stageOrder === proposal.stageOrder &&
      source.gddDelta != null
  );
  if (matching.length === 0) {
    return null;
  }

  const exceedanceCount = matching.filter(
    (source) => Math.abs(source.gddDelta ?? 0) > GDD_VARIANCE_THRESHOLD
  ).length;

  return {
    exceedanceCount,
    thresholdValue: GDD_VARIANCE_THRESHOLD,
    contributingRecords: toContributingRecords(sortByAbsDesc(matching, (row) => row.gddDelta)),
    totalRecordedCount: matching.length
  };
}

export function buildBlueprintTimingProposalEvidence(
  proposal: BlueprintTimingAdjustmentProposal,
  sources: ReadonlyArray<LearnProposalEvidenceSource>
): LearnProposalEvidence | null {
  const matching = sources.filter(
    (source) =>
      countsTowardEvidence(source) &&
      source.cropId === proposal.cropId &&
      source.category === proposal.category &&
      source.deltaDays != null
  );
  if (matching.length === 0) {
    return null;
  }

  const exceedanceCount = matching.filter(
    (source) => Math.abs(source.deltaDays ?? 0) > DAYS_VARIANCE_THRESHOLD
  ).length;

  return {
    exceedanceCount,
    thresholdValue: DAYS_VARIANCE_THRESHOLD,
    contributingRecords: toContributingRecords(sortByAbsDesc(matching, (row) => row.deltaDays)),
    totalRecordedCount: matching.length
  };
}

export function buildLearnProposalEvidenceMap<TProposal>(
  proposals: ReadonlyArray<TProposal>,
  sources: ReadonlyArray<LearnProposalEvidenceSource>,
  buildEvidence: (
    proposal: TProposal,
    sources: ReadonlyArray<LearnProposalEvidenceSource>
  ) => LearnProposalEvidence | null,
  keyOf: (proposal: TProposal) => string
): Record<string, LearnProposalEvidence> {
  const evidenceByKey: Record<string, LearnProposalEvidence> = {};
  for (const proposal of proposals) {
    const evidence = buildEvidence(proposal, sources);
    if (evidence) {
      evidenceByKey[keyOf(proposal)] = evidence;
    }
  }
  return evidenceByKey;
}
