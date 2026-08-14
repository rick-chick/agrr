import { TaskScheduleItem } from '../../models/plans/task-schedule';
import { parseGddTrigger } from '../plans/work-record-variance';

export type WorkRowGddGapState =
  | { kind: 'unavailable' }
  | { kind: 'reached'; trigger: number; cumulative: number }
  | { kind: 'shortfall'; trigger: number; cumulative: number; gap: number };

export function resolveWorkRowGddTrigger(item: TaskScheduleItem): number | null {
  const fromItem = item.gdd_trigger?.trim();
  const fromDetails = item.details?.gdd?.trigger?.trim();
  const raw = fromItem ? fromItem : fromDetails;
  return parseGddTrigger(raw ?? null);
}

export function resolveWorkRowWeatherDependency(item: TaskScheduleItem): string | null {
  const fromItem = item.weather_dependency?.trim();
  const fromDetails = item.details?.weather_dependency?.trim();
  const raw = fromItem ? fromItem : fromDetails;
  if (!raw || raw === 'none') {
    return null;
  }
  return raw;
}

export function resolveWorkRowGddGapState(
  trigger: number | null,
  cumulativeGddAtToday: number | null | undefined
): WorkRowGddGapState {
  if (trigger == null || cumulativeGddAtToday == null) {
    return { kind: 'unavailable' };
  }
  if (cumulativeGddAtToday >= trigger) {
    return { kind: 'reached', trigger, cumulative: cumulativeGddAtToday };
  }
  return {
    kind: 'shortfall',
    trigger,
    cumulative: cumulativeGddAtToday,
    gap: Math.round((trigger - cumulativeGddAtToday) * 10) / 10
  };
}

export function shouldShowWorkRowGddGapBadge(
  gapState: WorkRowGddGapState,
  hasGddExceedanceBadge: boolean
): boolean {
  if (gapState.kind === 'unavailable') {
    return false;
  }
  if (hasGddExceedanceBadge && gapState.kind === 'shortfall') {
    return false;
  }
  return true;
}
