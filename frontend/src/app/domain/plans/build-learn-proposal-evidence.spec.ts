import { describe, expect, it } from 'vitest';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  buildBlueprintTimingProposalEvidence,
  buildLearnProposalEvidenceMap,
  buildStageGddProposalEvidence,
  type LearnProposalEvidenceSource
} from './learn-proposal-evidence';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

const stageGddProposal: StageGddCalibrationProposal = {
  cropId: 42,
  cropName: 'Tomato',
  stageId: 501,
  stageOrder: 1,
  stageName: 'Vegetative',
  averageGddDelta: 12,
  recordedItemCount: 3,
  currentRequiredGdd: 120,
  proposedRequiredGdd: 132
};

const bpTimingProposal: BlueprintTimingAdjustmentProposal = {
  cropId: 42,
  cropName: 'Tomato',
  category: 'general',
  averageDeltaDays: 4,
  averageGddDelta: null,
  recordedItemCount: 3,
  affectedBlueprintCount: 2,
  proposalBody: {
    intent: 'blueprint_timing_patch',
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: []
  }
};

const sources: LearnProposalEvidenceSource[] = [
  {
    cropId: 42,
    category: 'general',
    stageOrder: 1,
    name: 'Transplant',
    actualDate: '2025-04-10',
    deltaDays: 5,
    gddDelta: 15,
    status: 'completed'
  },
  {
    cropId: 42,
    category: 'general',
    stageOrder: 1,
    name: 'Thinning',
    actualDate: '2025-04-12',
    deltaDays: 2,
    gddDelta: 8,
    status: 'completed'
  },
  {
    cropId: 42,
    category: 'general',
    stageOrder: 1,
    name: 'Weeding',
    actualDate: '2025-04-14',
    deltaDays: 6,
    gddDelta: 12,
    status: 'completed'
  },
  {
    cropId: 42,
    category: 'fertilizer',
    stageOrder: 2,
    name: 'Side dressing',
    actualDate: '2025-05-01',
    deltaDays: 1,
    gddDelta: 3,
    status: 'completed'
  }
];

describe('buildStageGddProposalEvidence', () => {
  it('returns threshold exceedance count and top contributing records by gdd delta', () => {
    const evidence = buildStageGddProposalEvidence(stageGddProposal, sources);

    expect(evidence).toEqual({
      exceedanceCount: 2,
      thresholdValue: 10,
      totalRecordedCount: 3,
      contributingRecords: [
        { name: 'Transplant', actualDate: '2025-04-10' },
        { name: 'Weeding', actualDate: '2025-04-14' },
        { name: 'Thinning', actualDate: '2025-04-12' }
      ]
    });
  });

  it('ignores skipped items and other stages', () => {
    const evidence = buildStageGddProposalEvidence(stageGddProposal, [
      ...sources,
      {
        cropId: 42,
        category: 'general',
        stageOrder: 1,
        name: 'Skipped task',
        actualDate: '2025-04-15',
        deltaDays: 10,
        gddDelta: 20,
        status: 'skipped'
      },
      {
        cropId: 42,
        category: 'general',
        stageOrder: 2,
        name: 'Other stage',
        actualDate: '2025-04-16',
        deltaDays: 10,
        gddDelta: 20,
        status: 'completed'
      }
    ]);

    expect(evidence?.totalRecordedCount).toBe(3);
    expect(evidence?.exceedanceCount).toBe(2);
  });
});

describe('buildBlueprintTimingProposalEvidence', () => {
  it('returns day threshold exceedance count and top contributing records by day delta', () => {
    const evidence = buildBlueprintTimingProposalEvidence(bpTimingProposal, sources);

    expect(evidence).toEqual({
      exceedanceCount: 2,
      thresholdValue: 3,
      totalRecordedCount: 3,
      contributingRecords: [
        { name: 'Weeding', actualDate: '2025-04-14' },
        { name: 'Transplant', actualDate: '2025-04-10' },
        { name: 'Thinning', actualDate: '2025-04-12' }
      ]
    });
  });
});

describe('buildLearnProposalEvidenceMap', () => {
  it('indexes evidence by proposal key', () => {
    const evidenceByKey = buildLearnProposalEvidenceMap(
      [stageGddProposal],
      sources,
      buildStageGddProposalEvidence,
      (proposal) => `${proposal.cropId}-${proposal.stageId}`
    );

    expect(Object.keys(evidenceByKey)).toEqual(['42-501']);
    expect(evidenceByKey['42-501']?.totalRecordedCount).toBe(3);
  });
});
