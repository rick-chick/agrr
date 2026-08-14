import { afterEach, describe, expect, it } from 'vitest';
import {
  bpTimingProposalProgressKey,
  buildLearnPostMasterNavigation,
  clearBlueprintTimingPrefill,
  clearLearnBpTimingApplyContext,
  clearLearnHandoffCache,
  clearLearnPostMasterPayload,
  clearLearnProposalApplicationProgressCache,
  confirmLearnProposalFromPostMaster,
  hydrateLearnHandoff,
  markAllConfirmedProposalsDone,
  markBpTimingProposalAppliedPending,
  markBpTimingProposalDismissed,
  markLearnProposalConfirmed,
  markLearnProposalDismissed,
  markStageGddProposalAppliedPending,
  markStageGddProposalDismissed,
  parsePlanLearnFollowUp,
  proposalKeyFromPostMasterPayload,
  readBlueprintTimingPrefill,
  readLearnBpTimingApplyContext,
  readLearnPostMasterPayload,
  readLearnProposalApplicationProgress,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey,
  storeBlueprintTimingPrefill,
  storeLearnBpTimingApplyContext,
  storeLearnPostMasterPayload,
  type LearnPostMasterPayload
} from './learn-proposal-application-progress';

const PLAN_ID = 7;

afterEach(() => {
  clearLearnHandoffCache();
  clearLearnProposalApplicationProgressCache();
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

  it('confirms proposal from post_master payload after applied_pending_confirmation', () => {
    const payload: LearnPostMasterPayload = {
      kind: 'stage_gdd',
      cropId: 1,
      cropName: 'Tomato',
      stageId: 2,
      stageName: 'Vegetative',
      appliedRequiredGdd: 150
    };
    markStageGddProposalAppliedPending(PLAN_ID, { cropId: 1, stageId: 2 });

    confirmLearnProposalFromPostMaster(PLAN_ID, payload);

    expect(proposalKeyFromPostMasterPayload(payload)).toBe(stageGddProposalProgressKey(1, 2));
    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, stageGddProposalProgressKey(1, 2))
    ).toBe('confirmed');
  });

  it('marks proposal as dismissed and persists in progress cache', () => {
    const key = stageGddProposalProgressKey(1, 2);
    markLearnProposalDismissed(PLAN_ID, key);

    expect(resolveLearnProposalApplicationStatus(PLAN_ID, key)).toBe('dismissed');
    expect(readLearnProposalApplicationProgress(PLAN_ID)).toEqual({
      [key]: 'dismissed'
    });
  });

  it('marks confirmed proposals as done', () => {
    const key = stageGddProposalProgressKey(1, 2);
    markStageGddProposalAppliedPending(PLAN_ID, { cropId: 1, stageId: 2 });
    markLearnProposalConfirmed(PLAN_ID, key);

    markAllConfirmedProposalsDone(PLAN_ID);

    expect(resolveLearnProposalApplicationStatus(PLAN_ID, key)).toBe('done');
  });

  it('builds proposal key from bp_timing post_master payload', () => {
    const payload: LearnPostMasterPayload = {
      kind: 'bp_timing',
      cropId: 4,
      cropName: 'Tomato',
      category: 'fertilizer'
    };

    expect(proposalKeyFromPostMasterPayload(payload)).toBe(
      bpTimingProposalProgressKey(4, 'fertilizer')
    );
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

  it('hydrates post_master payload from API snapshot', () => {
    hydrateLearnHandoff(PLAN_ID, { post_master_payload: payload });
    expect(readLearnPostMasterPayload(PLAN_ID)).toEqual(payload);
  });

  it('builds learn navigation with followUp=post_master', () => {
    expect(buildLearnPostMasterNavigation(PLAN_ID)).toEqual({
      commands: ['/plans', PLAN_ID, 'learn'],
      queryParams: { followUp: 'post_master' }
    });
  });
});

describe('parsePlanLearnFollowUp', () => {
  it('returns post_master only for exact match', () => {
    expect(parsePlanLearnFollowUp('post_master')).toBe('post_master');
    expect(parsePlanLearnFollowUp(null)).toBeNull();
    expect(parsePlanLearnFollowUp(undefined)).toBeNull();
    expect(parsePlanLearnFollowUp('')).toBeNull();
    expect(parsePlanLearnFollowUp('other')).toBeNull();
  });
});

describe('confirmLearnProposalFromPostMaster edge cases', () => {
  it('does not confirm when proposal is still not_started', () => {
    const payload: LearnPostMasterPayload = {
      kind: 'stage_gdd',
      cropId: 1,
      cropName: 'Tomato',
      stageId: 2,
      stageName: 'Vegetative'
    };

    confirmLearnProposalFromPostMaster(PLAN_ID, payload);

    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, stageGddProposalProgressKey(1, 2))
    ).toBe('not_started');
  });

  it('throws when stage_gdd payload lacks stageId', () => {
    const payload = {
      kind: 'stage_gdd' as const,
      cropId: 1,
      cropName: 'Tomato'
    };

    expect(() => proposalKeyFromPostMasterPayload(payload)).toThrow(
      'stageId is required for stage_gdd post_master payload'
    );
  });

  it('throws when bp_timing payload lacks category', () => {
    const payload = {
      kind: 'bp_timing' as const,
      cropId: 4,
      cropName: 'Tomato'
    };

    expect(() => proposalKeyFromPostMasterPayload(payload)).toThrow(
      'category is required for bp_timing post_master payload'
    );
  });
});

describe('dismiss learn proposals', () => {
  it('marks stage GDD proposal as dismissed in progress cache', () => {
    markStageGddProposalDismissed(PLAN_ID, { cropId: 1, stageId: 2 });

    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, stageGddProposalProgressKey(1, 2))
    ).toBe('dismissed');
  });

  it('marks BP timing proposal as dismissed in progress cache', () => {
    markBpTimingProposalDismissed(PLAN_ID, { cropId: 4, category: 'fertilizer' });

    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, bpTimingProposalProgressKey(4, 'fertilizer'))
    ).toBe('dismissed');
  });

  it('does not overwrite done status when dismissing', () => {
    const key = stageGddProposalProgressKey(1, 2);
    markStageGddProposalAppliedPending(PLAN_ID, { cropId: 1, stageId: 2 });
    markLearnProposalConfirmed(PLAN_ID, key);
    markAllConfirmedProposalsDone(PLAN_ID);

    markStageGddProposalDismissed(PLAN_ID, { cropId: 1, stageId: 2 });

    expect(resolveLearnProposalApplicationStatus(PLAN_ID, key)).toBe('done');
  });
});

describe('learn BP timing apply context', () => {
  it('stores, reads, and clears context per plan and crop', () => {
    const context = {
      planId: PLAN_ID,
      cropId: 4,
      cropName: 'Tomato',
      category: 'fertilizer'
    };

    storeLearnBpTimingApplyContext(PLAN_ID, context);
    expect(readLearnBpTimingApplyContext(PLAN_ID, 4)).toEqual(context);

    clearLearnBpTimingApplyContext(PLAN_ID, 4);
    expect(readLearnBpTimingApplyContext(PLAN_ID, 4)).toBeNull();
  });
});

describe('blueprint timing prefill handoff', () => {
  it('stores, reads, and clears blueprint prefill per plan and crop', () => {
    const body = {
      crop_name: 'Tomato',
      stages: [],
      agricultural_tasks: [],
      task_schedule_blueprints: []
    };

    storeBlueprintTimingPrefill(PLAN_ID, 4, body);
    expect(readBlueprintTimingPrefill(PLAN_ID, 4)).toEqual(body);

    clearBlueprintTimingPrefill(PLAN_ID, 4);
    expect(readBlueprintTimingPrefill(PLAN_ID, 4)).toBeNull();
  });
});
