import { WorkRecord } from '../../models/plans/work-record';

function parseIsoDateLocal(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function deltaDaysBetween(scheduled: string, actual: string): number {
  const msPerDay = 24 * 60 * 60 * 1000;
  const scheduledDate = parseIsoDateLocal(scheduled);
  const actualDate = parseIsoDateLocal(actual);
  return Math.round((actualDate.getTime() - scheduledDate.getTime()) / msPerDay);
}

export function workRecordScheduledDate(record: WorkRecord): string | null {
  return record.task_schedule_item?.scheduled_date ?? null;
}

export function workRecordDeltaDays(record: WorkRecord): number | null {
  if (record.task_schedule_item_id == null) {
    return null;
  }
  const scheduled = workRecordScheduledDate(record);
  if (!scheduled) {
    return null;
  }
  return deltaDaysBetween(scheduled, record.actual_date);
}

export function averageWorkRecordDeltaDays(records: WorkRecord[]): number | null {
  const deltas = records
    .map(workRecordDeltaDays)
    .filter((delta): delta is number => delta != null);
  if (deltas.length === 0) {
    return null;
  }
  const sum = deltas.reduce((total, delta) => total + delta, 0);
  return sum / deltas.length;
}

export function parseGddTrigger(value: string | number | null | undefined): number | null {
  if (value == null || value === '') {
    return null;
  }
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function gddDeltaFromValues(
  actual: number | null,
  planned: number | null
): number | null {
  if (actual == null || planned == null) {
    return null;
  }
  return Math.round((actual - planned) * 10) / 10;
}

export function workRecordGddDelta(
  record: WorkRecord,
  gddTrigger?: number | null
): number | null {
  const actual = record.gdd_at_actual;
  if (actual == null) {
    return null;
  }
  const trigger = gddTrigger ?? null;
  return gddDeltaFromValues(actual, trigger);
}

export function formatVarianceDeltaDays(delta: number): string {
  if (delta === 0) {
    return '±0';
  }
  return delta > 0 ? `+${delta}` : `${delta}`;
}

export function formatVarianceGddDelta(delta: number): string {
  if (delta === 0) {
    return '±0';
  }
  return delta > 0 ? `+${delta}` : `${delta}`;
}
