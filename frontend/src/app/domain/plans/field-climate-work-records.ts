import { WorkRecord } from '../../models/plans/work-record';
import { TaskScheduleItemVariance } from './task-schedule-variance-lookup';
import {
  formatVarianceDeltaDays,
  formatVarianceGddDelta,
  workRecordDeltaDays
} from './work-record-variance';

export type FieldClimateWorkDayMarker = {
  actualDate: string;
  name: string;
  taskScheduleItemId: number | null;
};

export type FieldClimateLatestImplementation = {
  name: string;
  deltaDaysLabel: string | null;
  gddDeltaLabel: string | null;
};

function sortWorkRecordsByRecency(records: WorkRecord[]): WorkRecord[] {
  return [...records].sort((left, right) => {
    const dateCompare = right.actual_date.localeCompare(left.actual_date);
    if (dateCompare !== 0) {
      return dateCompare;
    }
    return right.created_at.localeCompare(left.created_at);
  });
}

export function buildFieldClimateWorkDayMarkers(records: WorkRecord[]): FieldClimateWorkDayMarker[] {
  return sortWorkRecordsByRecency(records).map((record) => ({
    actualDate: record.actual_date,
    name: record.name,
    taskScheduleItemId: record.task_schedule_item_id
  }));
}

export function buildFieldClimateLatestImplementation(
  records: WorkRecord[],
  varianceByItemId?: Map<number, TaskScheduleItemVariance>
): FieldClimateLatestImplementation | null {
  const latest = sortWorkRecordsByRecency(records)[0];
  if (!latest) {
    return null;
  }

  const linkedVariance =
    latest.task_schedule_item_id != null
      ? varianceByItemId?.get(latest.task_schedule_item_id)
      : undefined;
  const deltaDays = linkedVariance?.deltaDays ?? workRecordDeltaDays(latest);
  const gddDelta = linkedVariance?.gddDelta ?? null;

  return {
    name: latest.name,
    deltaDaysLabel: deltaDays != null ? formatVarianceDeltaDays(deltaDays) : null,
    gddDeltaLabel: gddDelta != null ? formatVarianceGddDelta(gddDelta) : null
  };
}
