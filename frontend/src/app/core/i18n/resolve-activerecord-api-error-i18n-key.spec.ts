import { describe, expect, it } from 'vitest';
import {
  ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY,
  resolveActiverecordApiErrorI18nKey
} from './resolve-activerecord-api-error-i18n-key';

describe('resolveActiverecordApiErrorI18nKey', () => {
  it('maps Japanese farm limit message to activerecord i18n key', () => {
    expect(resolveActiverecordApiErrorI18nKey('作成できるFarmは4件までです')).toBe(
      ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY
    );
  });

  it('maps English farm limit message to activerecord i18n key', () => {
    expect(resolveActiverecordApiErrorI18nKey('You can create up to 4 Farms')).toBe(
      ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY
    );
  });

  it('returns unknown messages unchanged', () => {
    expect(resolveActiverecordApiErrorI18nKey('Validation failed')).toBe('Validation failed');
  });

  it('returns i18n key unchanged when already normalized', () => {
    expect(resolveActiverecordApiErrorI18nKey(ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY)).toBe(
      ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY
    );
  });
});
