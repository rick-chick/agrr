import { describe, expect, it } from 'vitest';

import { ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY } from '../../core/i18n/resolve-activerecord-api-error-i18n-key';
import {
  countUserOwnedFarms,
  isFarmCreateLimitReached,
  isFarmLimitExceededMessage,
  MAX_NON_REFERENCE_FARMS_PER_USER
} from './farm-create-limit';

describe('farm-create-limit', () => {
  it('counts only non-reference farms as user-owned', () => {
    expect(
      countUserOwnedFarms([
        { is_reference: false },
        { is_reference: true },
        { is_reference: false }
      ])
    ).toBe(2);
  });

  it('treats four user-owned farms as limit reached', () => {
    expect(isFarmCreateLimitReached(MAX_NON_REFERENCE_FARMS_PER_USER)).toBe(true);
    expect(isFarmCreateLimitReached(MAX_NON_REFERENCE_FARMS_PER_USER - 1)).toBe(false);
  });

  it('recognizes farm limit messages by activerecord i18n key or literal', () => {
    expect(isFarmLimitExceededMessage(ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY)).toBe(true);
    expect(isFarmLimitExceededMessage('作成できるFarmは4件までです')).toBe(true);
    expect(isFarmLimitExceededMessage('You can create up to 4 Farms')).toBe(true);
    expect(isFarmLimitExceededMessage('Failed to load farms')).toBe(false);
  });
});
