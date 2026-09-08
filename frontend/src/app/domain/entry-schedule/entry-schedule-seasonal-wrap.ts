/** 暦年をまたぐ「秋冬〜翌春夏」型の候補期間（例: 10/10–06/30） */
export function seasonalWrapsCalendarYear(startIso: string, endIso: string): boolean {
  const startYear = Number(startIso.slice(0, 4));
  const endYear = Number(endIso.slice(0, 4));
  if (!Number.isFinite(startYear) || !Number.isFinite(endYear) || endYear <= startYear) {
    return false;
  }
  return startIso.slice(5, 10) > endIso.slice(5, 10);
}
