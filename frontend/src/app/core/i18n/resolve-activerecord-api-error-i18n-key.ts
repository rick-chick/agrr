export const ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY =
  'activerecord.errors.models.farm.attributes.user.farm_limit_exceeded';

const ACTIVERECORD_ERROR_LITERAL_TO_KEY: Readonly<Record<string, string>> = {
  '作成できるFarmは4件までです': ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY,
  'You can create up to 4 Farms': ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY
};

/**
 * Maps server-side ActiveRecord error literals (translated on the API) to ngx-translate keys.
 */
export function resolveActiverecordApiErrorI18nKey(message: string): string {
  const trimmed = message.trim();
  return ACTIVERECORD_ERROR_LITERAL_TO_KEY[trimmed] ?? trimmed;
}
