import {
  ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY,
  resolveActiverecordApiErrorI18nKey
} from '../../core/i18n/resolve-activerecord-api-error-i18n-key';
import { Farm } from './farm';

/** Matches `FarmCreateLimitPolicy::MAX_NON_REFERENCE_FARMS_PER_USER` in agrr-domain. */
export const MAX_NON_REFERENCE_FARMS_PER_USER = 4;

export function countUserOwnedFarms(farms: Array<Pick<Farm, 'is_reference'>>): number {
  return farms.filter((farm) => farm.is_reference !== true).length;
}

export function isFarmCreateLimitReached(ownedFarmCount: number): boolean {
  return ownedFarmCount >= MAX_NON_REFERENCE_FARMS_PER_USER;
}

export function isFarmLimitExceededMessage(message: string): boolean {
  return resolveActiverecordApiErrorI18nKey(message) === ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY;
}
