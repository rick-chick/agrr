import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';

export function collectPlanTaskScheduleUnrecordedRows(
  rows: ReadonlyArray<CrossFarmScheduleRow>
): CrossFarmScheduleRow[] {
  return rows.filter((row) => {
    const { item } = row;
    if (item.status.toLowerCase() === 'skipped') {
      return false;
    }
    if (item.scheduled_date == null) {
      return false;
    }
    return item.actualDate == null;
  });
}
