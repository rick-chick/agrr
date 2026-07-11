import type {
  CrossFarmScheduleFilter,
  CrossFarmScheduleFilterOption,
  CrossFarmScheduleRow
} from './cross-farm-schedule-row';

export interface CrossFarmScheduleFilterOptions {
  farms: CrossFarmScheduleFilterOption[];
  fields: CrossFarmScheduleFilterOption[];
}

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

export function filterCrossFarmScheduleRows(
  rows: ReadonlyArray<CrossFarmScheduleRow>,
  filter: CrossFarmScheduleFilter
): CrossFarmScheduleRow[] {
  return rows.filter((row) => {
    if (filter.farmId != null && row.farmId !== filter.farmId) {
      return false;
    }
    if (filter.fieldCultivationId != null && row.fieldCultivationId !== filter.fieldCultivationId) {
      return false;
    }
    return true;
  });
}

export function buildCrossFarmScheduleFilterOptions(
  rows: ReadonlyArray<CrossFarmScheduleRow>,
  selectedFarmId: number | null
): CrossFarmScheduleFilterOptions {
  const farms = uniqueOptions(
    rows,
    (row) => row.farmId,
    (row) => row.farmName
  );
  const fieldSource =
    selectedFarmId == null ? rows : rows.filter((row) => row.farmId === selectedFarmId);
  const fields = uniqueOptions(
    fieldSource,
    (row) => row.fieldCultivationId,
    (row) => row.fieldName
  );
  return { farms, fields };
}
