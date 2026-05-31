export type PlanDisplayNameTranslate = (
  key: string,
  params?: Record<string, string>
) => string;

const JAPANESE_FARM_PLAN_SUFFIX = /^(.+)の計画$/u;
const LEGACY_YEAR_SUFFIX = /^(.+) \((\d{4})\)$/u;

/**
 * DB に保存された「{農場名}の計画」形式を、現在の UI 言語の計画名に直す。
 * カスタム計画名はそのまま返す。
 */
export function localizePlanDisplayName(
  storedName: string | null | undefined,
  instant: PlanDisplayNameTranslate
): string {
  const trimmed = storedName?.trim() ?? '';
  if (!trimmed) {
    return '';
  }

  let base = trimmed;
  let yearSuffix: string | null = null;
  const yearMatch = base.match(LEGACY_YEAR_SUFFIX);
  if (yearMatch) {
    base = yearMatch[1];
    yearSuffix = yearMatch[2];
  }

  const farmMatch = base.match(JAPANESE_FARM_PLAN_SUFFIX);
  if (farmMatch) {
    base = instant('plans.display_name_from_farm', { farmName: farmMatch[1].trim() });
  }

  return yearSuffix ? `${base} (${yearSuffix})` : base;
}
