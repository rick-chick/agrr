import type { WeatherRescheduleAdjustMove } from './weather-reschedule-proposal-preview';

export function computeWeatherRescheduleDelayDays(
  currentStartDate: string,
  moves: WeatherRescheduleAdjustMove[]
): number | null {
  const move = moves.find((m) => m.action === 'move');
  if (!move?.to_start_date) {
    return null;
  }
  const current = parseIsoDateOnly(currentStartDate);
  const proposed = parseIsoDateOnly(move.to_start_date);
  if (!current || !proposed) {
    return null;
  }
  const diffMs = proposed.getTime() - current.getTime();
  return Math.round(diffMs / (24 * 60 * 60 * 1000));
}

function parseIsoDateOnly(value: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  if (!match) {
    return null;
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(year, month - 1, day);
  if (
    date.getFullYear() !== year ||
    date.getMonth() !== month - 1 ||
    date.getDate() !== day
  ) {
    return null;
  }
  return date;
}
