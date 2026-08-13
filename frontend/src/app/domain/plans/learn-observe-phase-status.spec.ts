import { describe, expect, it } from 'vitest';
import {
  isLearnObservePhaseComplete,
  shouldShowLearnUnrecordedCta
} from './learn-observe-phase-status';

describe('learn-observe-phase-status', () => {
  describe('shouldShowLearnUnrecordedCta', () => {
    it('returns true when variance is loaded and unrecorded_count is positive', () => {
      expect(shouldShowLearnUnrecordedCta({ unrecordedCount: 3, varianceLoaded: true })).toBe(true);
    });

    it('returns false when unrecorded_count is zero', () => {
      expect(shouldShowLearnUnrecordedCta({ unrecordedCount: 0, varianceLoaded: true })).toBe(false);
    });

    it('returns false while variance is still loading', () => {
      expect(shouldShowLearnUnrecordedCta({ unrecordedCount: 2, varianceLoaded: false })).toBe(false);
    });
  });

  describe('isLearnObservePhaseComplete', () => {
    it('returns true when variance is loaded and all tasks are recorded', () => {
      expect(isLearnObservePhaseComplete({ unrecordedCount: 0, varianceLoaded: true })).toBe(true);
    });

    it('returns false when unrecorded tasks remain', () => {
      expect(isLearnObservePhaseComplete({ unrecordedCount: 1, varianceLoaded: true })).toBe(false);
    });

    it('returns false while variance is still loading', () => {
      expect(isLearnObservePhaseComplete({ unrecordedCount: 0, varianceLoaded: false })).toBe(false);
    });
  });
});
