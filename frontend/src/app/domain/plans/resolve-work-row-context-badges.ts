import type { TaskScheduleItem } from '../../models/plans/task-schedule';
import { parseGddTrigger } from './work-record-variance';

export type WorkRowGddContextState = 'trigger_only' | 'reached' | 'remaining';

export type WorkRowGddContext = {
  trigger: number;
  state: WorkRowGddContextState;
  remaining?: number;
  gddAtActual?: number;
};

const WEATHER_DEPENDENCY_NONE = new Set(['', 'none']);

export function resolveWorkRowGddTrigger(
  item: Pick<TaskScheduleItem, 'gdd_trigger' | 'details'>
): number | null {
  return (
    parseGddTrigger(item.gdd_trigger) ?? parseGddTrigger(item.details?.gdd?.trigger ?? null)
  );
}

export function resolveWorkRowGddContext(
  item: Pick<TaskScheduleItem, 'gdd_trigger' | 'gdd_at_actual' | 'gdd_delta' | 'details'>
): WorkRowGddContext | null {
  const trigger = resolveWorkRowGddTrigger(item);
  if (trigger == null) {
    return null;
  }

  const gddAtActual = item.gdd_at_actual ?? null;
  if (gddAtActual == null) {
    return { trigger, state: 'trigger_only' };
  }

  const delta = item.gdd_delta ?? gddAtActual - trigger;
  if (delta >= 0) {
    return { trigger, state: 'reached', gddAtActual };
  }

  return {
    trigger,
    state: 'remaining',
    remaining: Math.round(Math.abs(delta) * 10) / 10,
    gddAtActual
  };
}

export function shouldShowWorkRowGddProgress(
  context: WorkRowGddContext,
  hasGddExceedanceBadge: boolean
): boolean {
  if (hasGddExceedanceBadge) {
    return false;
  }
  return context.state === 'reached' || context.state === 'remaining';
}

export function resolveWorkRowWeatherDependency(
  item: Pick<TaskScheduleItem, 'weather_dependency' | 'details'>
): string | null {
  const raw = (item.weather_dependency || item.details?.weather_dependency || '').trim().toLowerCase();
  if (WEATHER_DEPENDENCY_NONE.has(raw)) {
    return null;
  }
  return raw;
}
