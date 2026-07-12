import type {
  CrossFarmScheduleFilterOption,
  CrossFarmScheduleRow
} from './cross-farm-schedule-row';

function uniqueOptions(
  rows: ReadonlyArray<CrossFarmScheduleRow>,
  valueKey: (row: CrossFarmScheduleRow) => number,
  labelKey: (row: CrossFarmScheduleRow) => string
): CrossFarmScheduleFilterOption[] {
  const seen = new Map<number, string>();
  for (const row of rows) {
    const value = valueKey(row);
    if (!seen.has(value)) {
      seen.set(value, labelKey(row));
    }
  }
  return [...seen.entries()]
    .map(([value, label]) => ({ value, label }))
    .sort((left, right) => left.label.localeCompare(right.label, 'ja'));
}

export function filterPlanTaskScheduleRows(
  rows: ReadonlyArray<CrossFarmScheduleRow>,
  fieldCultivationId: number | null
): CrossFarmScheduleRow[] {
  if (fieldCultivationId == null) {
    return [...rows];
  }
  return rows.filter((row) => row.fieldCultivationId === fieldCultivationId);
}

export function filterCrossFarmScheduleRowsFromDate(
  rows: ReadonlyArray<CrossFarmScheduleRow>,
  fromDate: string
): CrossFarmScheduleRow[] {
  return rows.filter((row) => {
    const scheduledDate = row.item.scheduled_date;
    return scheduledDate != null && scheduledDate !== '' && scheduledDate >= fromDate;
  });
}

export function buildPlanTaskScheduleFieldFilterOptions(
  rows: ReadonlyArray<CrossFarmScheduleRow>
): CrossFarmScheduleFilterOption[] {
  return uniqueOptions(
    rows,
    (row) => row.fieldCultivationId,
    (row) => row.fieldName
  );
}
