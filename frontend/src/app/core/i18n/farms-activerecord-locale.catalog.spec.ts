import { describe, expect, it } from 'vitest';
import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';
import { ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY } from './resolve-activerecord-api-error-i18n-key';

type FarmLimitBundle = {
  activerecord?: {
    errors?: {
      models?: {
        farm?: {
          attributes?: {
            user?: { farm_limit_exceeded?: string };
          };
        };
      };
    };
  };
};

function activerecordFarmUserLimit(bundle: unknown): string | undefined {
  return (bundle as FarmLimitBundle).activerecord?.errors?.models?.farm?.attributes?.user
    ?.farm_limit_exceeded;
}

describe('farm limit activerecord i18n catalog', () => {
  it('defines farm_limit_exceeded in ja, en, and in', () => {
    for (const [name, bundle, expected] of [
      ['ja', ja, '作成できるFarmは4件までです'],
      ['en', en, 'You can create up to 4 Farms'],
      ['in', inLocale, 'आप अधिकतम 4 Farm बना सकते हैं']
    ] as const) {
      expect(activerecordFarmUserLimit(bundle), `${name}:farm_limit_exceeded`).toBe(expected);
    }
  });

  it('uses the shared activerecord key constant', () => {
    expect(ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY).toBe(
      'activerecord.errors.models.farm.attributes.user.farm_limit_exceeded'
    );
  });
});
