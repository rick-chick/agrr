import { describe, expect, it } from 'vitest';
import { resolveLearnProposalConfidence } from './resolve-learn-proposal-confidence';

describe('resolveLearnProposalConfidence', () => {
  it('returns low when unrecorded tasks exist', () => {
    expect(
      resolveLearnProposalConfidence({ unrecordedCount: 2, actionRequiredCount: 5 })
    ).toBe('low');
  });

  it('returns medium when action-required items exist and nothing is unrecorded', () => {
    expect(
      resolveLearnProposalConfidence({ unrecordedCount: 0, actionRequiredCount: 3 })
    ).toBe('medium');
  });

  it('returns high when there are no input gaps', () => {
    expect(
      resolveLearnProposalConfidence({ unrecordedCount: 0, actionRequiredCount: 0 })
    ).toBe('high');
  });
});
