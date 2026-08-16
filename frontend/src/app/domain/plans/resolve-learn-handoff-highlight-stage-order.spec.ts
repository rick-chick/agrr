import { describe, expect, it, beforeEach } from 'vitest';
import {
  clearLearnHandoffCache,
  storeLearnBpAmountApplyContext
} from './learn-proposal-application-progress';
import { resolveLearnHandoffHighlightStageOrder } from './resolve-learn-handoff-highlight-stage-order';

const PLAN_ID = 7;
const CROP_ID = 42;

beforeEach(() => {
  clearLearnHandoffCache();
});

describe('resolveLearnHandoffHighlightStageOrder', () => {
  it('prefers handoffHighlightStageOrder query param over apply context', () => {
    storeLearnBpAmountApplyContext(PLAN_ID, {
      planId: PLAN_ID,
      cropId: CROP_ID,
      cropName: 'Tomato',
      category: 'fertilizer',
      taskType: 'fertilize',
      stageOrder: 2
    });

    expect(resolveLearnHandoffHighlightStageOrder('3', PLAN_ID, CROP_ID)).toBe(3);
  });

  it('falls back to bp_amount apply context when query is absent', () => {
    storeLearnBpAmountApplyContext(PLAN_ID, {
      planId: PLAN_ID,
      cropId: CROP_ID,
      cropName: 'Tomato',
      category: 'fertilizer',
      taskType: 'fertilize',
      stageOrder: 2
    });

    expect(resolveLearnHandoffHighlightStageOrder(null, PLAN_ID, CROP_ID)).toBe(2);
  });

  it('returns null when neither query nor context is available', () => {
    expect(resolveLearnHandoffHighlightStageOrder(null, PLAN_ID, CROP_ID)).toBeNull();
    expect(resolveLearnHandoffHighlightStageOrder(null, null, CROP_ID)).toBeNull();
  });
});
