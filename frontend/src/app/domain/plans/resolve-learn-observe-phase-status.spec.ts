import { describe, expect, it } from 'vitest';
import { resolveLearnObservePhaseStatus } from './resolve-learn-observe-phase-status';

describe('resolveLearnObservePhaseStatus', () => {
  it('returns null while variance is loading', () => {
    expect(
      resolveLearnObservePhaseStatus({
        varianceLoading: true,
        varianceError: null,
        unrecordedCount: null
      })
    ).toBeNull();
  });

  it('returns null when variance failed to load', () => {
    expect(
      resolveLearnObservePhaseStatus({
        varianceLoading: false,
        varianceError: 'plans.errors.load_failed',
        unrecordedCount: null
      })
    ).toBeNull();
  });

  it('returns unrecorded when unrecorded_count is positive', () => {
    expect(
      resolveLearnObservePhaseStatus({
        varianceLoading: false,
        varianceError: null,
        unrecordedCount: 3
      })
    ).toBe('unrecorded');
  });

  it('returns complete when unrecorded_count is zero and variance is loaded', () => {
    expect(
      resolveLearnObservePhaseStatus({
        varianceLoading: false,
        varianceError: null,
        unrecordedCount: 0
      })
    ).toBe('complete');
  });
});
