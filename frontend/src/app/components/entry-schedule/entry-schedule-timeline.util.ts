/**
 * エントリ作物スケジュールのガント横軸: 指定暦年の1月1日〜12月31日（ローカル日付）
 */
export function calendarYearJanDecBounds(year: number): { min: number; max: number; year: number } {
  const min = new Date(year, 0, 1).getTime();
  const max = new Date(year, 11, 31, 23, 59, 59, 999).getTime();
  return { min, max, year };
}

export const MONTH_NUMBERS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] as const;
