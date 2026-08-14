import { describe, expect, it } from 'vitest';
import { resolveLearnProposalConfidence } from './resolve-learn-proposal-confidence';

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
