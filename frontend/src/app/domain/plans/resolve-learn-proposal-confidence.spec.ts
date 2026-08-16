import { describe, expect, it } from 'vitest';
import type { BlueprintAmountAdjustmentProposal } from './blueprint-amount-adjustment-proposal';
import type { LearnProposalEvidenceSource } from './learn-proposal-evidence';
import {
  detectBpAmountProposalUnitMismatch,
  resolveBpAmountProposalConfidence,
  resolveLearnProposalConfidence
} from './resolve-learn-proposal-confidence';

const bpAmountProposal: BlueprintAmountAdjustmentProposal = {
  cropId: 1,
  cropName: 'Tomato',
  category: 'fertilizer',
  taskType: 'fertilize',
  stageOrder: 1,
  stageName: 'Vegetative',
  averageAmountDelta: 0.8,
  recordedItemCount: 3,
  amountUnit: 'kg',
  affectedBlueprintCount: 1,
  proposalBody: {
    intent: 'blueprint_amount_patch',
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: []
  }
};

describe('resolveBpAmountProposalConfidence', () => {
  it('returns low when plan-level unrecorded tasks remain', () => {
    expect(
      resolveBpAmountProposalConfidence({
        planUnrecordedCount: 1,
        planActionRequiredCount: 0,
        proposal: bpAmountProposal,
        evidence: { exceedanceCount: 2, thresholdValue: 0.5, contributingRecords: [], totalRecordedCount: 3 }
      })
    ).toBe('low');
  });

  it('returns low when stage has fewer than two contributing records', () => {
    expect(
      resolveBpAmountProposalConfidence({
        planUnrecordedCount: 0,
        planActionRequiredCount: 0,
        proposal: { ...bpAmountProposal, recordedItemCount: 1 },
        evidence: { exceedanceCount: 0, thresholdValue: 0.5, contributingRecords: [], totalRecordedCount: 1 }
      })
    ).toBe('low');
  });

  it('returns low when contributing records use mixed amount units', () => {
    expect(
      resolveBpAmountProposalConfidence({
        planUnrecordedCount: 0,
        planActionRequiredCount: 0,
        proposal: bpAmountProposal,
        hasUnitMismatch: true,
        evidence: { exceedanceCount: 2, thresholdValue: 0.5, contributingRecords: [], totalRecordedCount: 3 }
      })
    ).toBe('low');
  });

  it('returns medium when plan has action-required variance but stage data is adequate', () => {
    expect(
      resolveBpAmountProposalConfidence({
        planUnrecordedCount: 0,
        planActionRequiredCount: 2,
        proposal: { ...bpAmountProposal, recordedItemCount: 2 },
        evidence: { exceedanceCount: 1, thresholdValue: 0.5, contributingRecords: [], totalRecordedCount: 2 }
      })
    ).toBe('medium');
  });

  it('returns high when stage has three or more records and clear amount variance', () => {
    expect(
      resolveBpAmountProposalConfidence({
        planUnrecordedCount: 0,
        planActionRequiredCount: 0,
        proposal: bpAmountProposal,
        evidence: { exceedanceCount: 2, thresholdValue: 0.5, contributingRecords: [], totalRecordedCount: 3 }
      })
    ).toBe('high');
  });

  it('allows mixed confidence across stages on the same learn screen', () => {
    const highStage = resolveBpAmountProposalConfidence({
      planUnrecordedCount: 0,
      planActionRequiredCount: 0,
      proposal: { ...bpAmountProposal, recordedItemCount: 3 },
      evidence: { exceedanceCount: 2, thresholdValue: 0.5, contributingRecords: [], totalRecordedCount: 3 }
    });
    const lowStage = resolveBpAmountProposalConfidence({
      planUnrecordedCount: 0,
      planActionRequiredCount: 0,
      proposal: { ...bpAmountProposal, recordedItemCount: 1 },
      evidence: { exceedanceCount: 0, thresholdValue: 0.5, contributingRecords: [], totalRecordedCount: 1 }
    });

    expect(highStage).toBe('high');
    expect(lowStage).toBe('low');
  });
});

describe('detectBpAmountProposalUnitMismatch', () => {
  const sources: LearnProposalEvidenceSource[] = [
    {
      cropId: 1,
      category: 'fertilizer',
      taskType: 'fertilize',
      stageOrder: 1,
      name: 'Basal dressing',
      actualDate: '2025-04-10',
      deltaDays: null,
      gddDelta: null,
      amountDelta: 0.8,
      amountUnit: 'kg',
      status: 'completed'
    },
    {
      cropId: 1,
      category: 'fertilizer',
      taskType: 'fertilize',
      stageOrder: 1,
      name: 'Top dressing',
      actualDate: '2025-04-12',
      deltaDays: null,
      gddDelta: null,
      amountDelta: 0.4,
      amountUnit: 'L',
      status: 'completed'
    }
  ];

  it('detects mixed units among stage-matched contributing records', () => {
    expect(detectBpAmountProposalUnitMismatch(bpAmountProposal, sources)).toBe(true);
  });

  it('returns false when all matched records share the proposal unit', () => {
    expect(
      detectBpAmountProposalUnitMismatch(bpAmountProposal, [
        { ...sources[0]! },
        { ...sources[0]!, name: 'Second dressing', amountDelta: 0.2 }
      ])
    ).toBe(false);
  });
});

describe('resolveLearnProposalConfidence', () => {
  it('returns low when unrecorded tasks remain', () => {
    expect(
      resolveLearnProposalConfidence({ unrecordedCount: 2, actionRequiredCount: 1 })
    ).toBe('low');
  });

  it('returns medium when only action-required variance remains', () => {
    expect(
      resolveLearnProposalConfidence({ unrecordedCount: 0, actionRequiredCount: 3 })
    ).toBe('medium');
  });

  it('returns high when observation data is complete', () => {
    expect(
      resolveLearnProposalConfidence({ unrecordedCount: 0, actionRequiredCount: 0 })
    ).toBe('high');
  });
});
