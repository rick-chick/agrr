import { describe, expect, it } from 'vitest';
import type { BlueprintAmountAdjustmentProposal } from './blueprint-amount-adjustment-proposal';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  buildBlueprintAmountProposalEvidence,
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

const bpAmountProposal: BlueprintAmountAdjustmentProposal = {
  cropId: 42,
  cropName: 'Tomato',
  category: 'fertilizer',
  taskType: 'fertilize',
  stageOrder: 1,
  stageName: 'Vegetative',
  averageAmountDelta: 0.8,
  recordedItemCount: 2,
  amountUnit: 'kg',
  affectedBlueprintCount: 1,
  proposalBody: {
    intent: 'blueprint_amount_patch',
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: []
  }
};

const sources: LearnProposalEvidenceSource[] = [
  {
    cropId: 42,
    category: 'general',
    taskType: null,
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
    taskType: 'fertilize',
    stageOrder: 2,
    name: 'Side dressing',
    actualDate: '2025-05-01',
    deltaDays: 1,
    gddDelta: 3,
    amountDelta: 0.9,
    status: 'completed'
  },
  {
    cropId: 42,
    category: 'fertilizer',
    taskType: 'fertilize',
    stageOrder: 2,
    name: 'Basal',
    actualDate: '2025-05-02',
    deltaDays: 0,
    gddDelta: 1,
    amountDelta: 0.2,
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

describe('buildBlueprintAmountProposalEvidence', () => {
  it('matches contributing records by crop, category, task_type, and stage_order', () => {
    const stageOneSources: LearnProposalEvidenceSource[] = [
      {
        cropId: 42,
        category: 'fertilizer',
        taskType: 'fertilize',
        stageOrder: 1,
        name: 'Basal dressing',
        actualDate: '2025-04-10',
        deltaDays: null,
        gddDelta: null,
        amountDelta: 0.9,
        status: 'completed'
      },
      {
        cropId: 42,
        category: 'fertilizer',
        taskType: 'fertilize',
        stageOrder: 1,
        name: 'Top dressing',
        actualDate: '2025-04-12',
        deltaDays: null,
        gddDelta: null,
        amountDelta: 0.2,
        status: 'completed'
      },
      {
        cropId: 42,
        category: 'fertilizer',
        taskType: 'fertilize',
        stageOrder: 2,
        name: 'Side dressing',
        actualDate: '2025-05-01',
        deltaDays: null,
        gddDelta: null,
        amountDelta: 1.5,
        status: 'completed'
      }
    ];

    const evidence = buildBlueprintAmountProposalEvidence(bpAmountProposal, stageOneSources);

    expect(evidence).toEqual({
      exceedanceCount: 1,
      thresholdValue: 0.5,
      totalRecordedCount: 2,
      contributingRecords: [
        { name: 'Basal dressing', actualDate: '2025-04-10' },
        { name: 'Top dressing', actualDate: '2025-04-12' }
      ]
    });
  });

  it('ignores records from other stages even when task_type matches', () => {
    const onlyOtherStage: LearnProposalEvidenceSource[] = [
      {
        cropId: 42,
        category: 'fertilizer',
        taskType: 'fertilize',
        stageOrder: 2,
        name: 'Side dressing',
        actualDate: '2025-05-01',
        deltaDays: null,
        gddDelta: null,
        amountDelta: 0.9,
        status: 'completed'
      }
    ];

    expect(buildBlueprintAmountProposalEvidence(bpAmountProposal, onlyOtherStage)).toBeNull();
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
