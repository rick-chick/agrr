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
  fieldFilterId: number | null,
  fieldCultivationFilterId: number | null = null
): CrossFarmScheduleRow[] {
  if (fieldCultivationFilterId != null) {
    return rows.filter((row) => row.fieldCultivationId === fieldCultivationFilterId);
  }
  if (fieldFilterId != null) {
    return rows.filter((row) => row.fieldId === fieldFilterId);
  }
  return [...rows];
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
    (row) => row.fieldId,
    (row) => row.fieldName
  );
}
