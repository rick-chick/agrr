import { describe, expect, it } from 'vitest';
import { countAddressedLearnApplicationProgress } from './learn-application-progress-summary';

describe('countAddressedLearnApplicationProgress', () => {
  it('counts non-not_started statuses as addressed', () => {
    expect(
      countAddressedLearnApplicationProgress(['not_started', 'confirmed', 'dismissed', 'done'])
    ).toEqual({ addressed: 3, total: 4 });
  });

  it('returns zero addressed when all not_started', () => {
    expect(countAddressedLearnApplicationProgress(['not_started', 'not_started'])).toEqual({
      addressed: 0,
      total: 2
    });
  });
});
