import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';

export interface CrossFarmScheduleMonthGroup {
  monthKey: string;
  rows: CrossFarmScheduleRow[];
}

export function groupCrossFarmScheduleByMonth(
  rows: ReadonlyArray<CrossFarmScheduleRow>
): CrossFarmScheduleMonthGroup[] {
  const map = new Map<string, CrossFarmScheduleRow[]>();

  for (const row of rows) {
    const scheduledDate = row.item.scheduled_date;
    if (!scheduledDate) {
      continue;
    }
    const monthKey = scheduledDate.slice(0, 7);
    const bucket = map.get(monthKey) ?? [];
    bucket.push(row);
    map.set(monthKey, bucket);
  }

  return [...map.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([monthKey, groupRows]) => ({
      monthKey,
      rows: [...groupRows].sort((left, right) => {
        const dateCmp = (left.item.scheduled_date ?? '').localeCompare(right.item.scheduled_date ?? '');
        if (dateCmp !== 0) {
          return dateCmp;
        }
        return left.item.name.localeCompare(right.item.name);
      })
    }));
}
