import { describe, expect, it } from 'vitest';
import { parseFromPlanId } from './parse-from-plan-id';

describe('parseFromPlanId', () => {
  it('returns null for missing or invalid query values', () => {
    expect(parseFromPlanId(null)).toBeNull();
    expect(parseFromPlanId('0')).toBeNull();
    expect(parseFromPlanId('abc')).toBeNull();
  });

  it('returns positive numeric plan id', () => {
    expect(parseFromPlanId('7')).toBe(7);
  });
});
