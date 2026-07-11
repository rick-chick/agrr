import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';

export interface CrossFarmScheduleMonthGroup {
  monthKey: string;
  rows: CrossFarmScheduleRow[];
}

function isoMonthKey(scheduledDate: string): string | null {
  const match = /^(\d{4})-(\d{2})-\d{2}$/.exec(scheduledDate);
  return match ? `${match[1]}-${match[2]}` : null;
}

function compareRows(left: CrossFarmScheduleRow, right: CrossFarmScheduleRow): number {
  const leftDate = left.item.scheduled_date ?? '';
  const rightDate = right.item.scheduled_date ?? '';
  if (leftDate !== rightDate) {
    return leftDate.localeCompare(rightDate);
  }
  return left.item.item_id - right.item.item_id;
}

export function groupCrossFarmScheduleRowsByMonth(
  rows: ReadonlyArray<CrossFarmScheduleRow>
): CrossFarmScheduleMonthGroup[] {
  const grouped = new Map<string, CrossFarmScheduleRow[]>();

  for (const row of rows) {
    const scheduledDate = row.item.scheduled_date;
    if (!scheduledDate) {
      continue;
    }
    const monthKey = isoMonthKey(scheduledDate);
    if (!monthKey) {
      continue;
    }
    const bucket = grouped.get(monthKey);
    if (bucket) {
      bucket.push(row);
    } else {
      grouped.set(monthKey, [row]);
    }
  }

  return [...grouped.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([monthKey, monthRows]) => ({
      monthKey,
      rows: [...monthRows].sort(compareRows)
    }));
}
