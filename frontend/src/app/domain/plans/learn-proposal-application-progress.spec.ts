import { afterEach, describe, expect, it } from 'vitest';
import {
  bpTimingProposalProgressKey,
  buildLearnPostMasterNavigation,
  clearLearnPostMasterPayload,
  markBpTimingProposalAppliedPending,
  markStageGddProposalAppliedPending,
  readLearnPostMasterPayload,
  readLearnProposalApplicationProgress,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey,
  storeLearnPostMasterPayload,
  type LearnPostMasterPayload
} from './learn-proposal-application-progress';

const PLAN_ID = 7;

afterEach(() => {
  sessionStorage.clear();
});

describe('learn proposal application progress keys', () => {
  it('builds stable keys for stage GDD and BP timing proposals', () => {
    expect(stageGddProposalProgressKey(3, 12)).toBe('stage_gdd:3:12');
    expect(bpTimingProposalProgressKey(3, 'general')).toBe('bp_timing:3:general');
  });
});

describe('learn proposal application progress storage', () => {
  it('defaults to not_started when no record exists', () => {
    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, stageGddProposalProgressKey(1, 2))
    ).toBe('not_started');
  });

  it('marks stage GDD proposal as applied_pending_confirmation', () => {
    markStageGddProposalAppliedPending(PLAN_ID, {
      cropId: 1,
      stageId: 2
    });

    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, stageGddProposalProgressKey(1, 2))
    ).toBe('applied_pending_confirmation');
    expect(readLearnProposalApplicationProgress(PLAN_ID)).toEqual({
      [stageGddProposalProgressKey(1, 2)]: 'applied_pending_confirmation'
    });
  });

  it('marks BP timing proposal as applied_pending_confirmation', () => {
    markBpTimingProposalAppliedPending(PLAN_ID, {
      cropId: 4,
      category: 'fertilizer'
    });

    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, bpTimingProposalProgressKey(4, 'fertilizer'))
    ).toBe('applied_pending_confirmation');
  });
});

describe('learn post_master payload', () => {
  const payload: LearnPostMasterPayload = {
    kind: 'stage_gdd',
    cropId: 1,
    cropName: 'Tomato',
    stageId: 2,
    stageName: 'Vegetative',
    appliedRequiredGdd: 150
  };

  it('stores and reads post_master payload per plan', () => {
    storeLearnPostMasterPayload(PLAN_ID, payload);
    expect(readLearnPostMasterPayload(PLAN_ID)).toEqual(payload);
    clearLearnPostMasterPayload(PLAN_ID);
    expect(readLearnPostMasterPayload(PLAN_ID)).toBeNull();
  });

  it('builds learn navigation with followUp=post_master', () => {
    expect(buildLearnPostMasterNavigation(PLAN_ID)).toEqual({
      commands: ['/plans', PLAN_ID, 'learn'],
      queryParams: { followUp: 'post_master' }
    });
  });
});
