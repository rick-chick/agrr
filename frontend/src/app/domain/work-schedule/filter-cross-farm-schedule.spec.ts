import { describe, expect, it } from 'vitest';
import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';
import {
  buildPlanTaskScheduleFieldFilterOptions,
  filterPlanTaskScheduleRows,
  filterCrossFarmScheduleRowsFromDate
} from './filter-cross-farm-schedule';

function mockRow(
  overrides: Partial<CrossFarmScheduleRow> & Pick<CrossFarmScheduleRow, 'farmId' | 'fieldCultivationId'>
): CrossFarmScheduleRow {
  return {
    item: {
      item_id: 1,
      name: 'Task',
      scheduled_date: '2026-06-10'
    } as CrossFarmScheduleRow['item'],
    farmName: 'Farm A',
    planId: 10,
    planName: 'Plan A',
    fieldId: overrides.fieldId ?? overrides.fieldCultivationId,
    fieldName: 'Field 1',
    cropName: 'Tomato',
    ...overrides
  };
}

describe('filterPlanTaskScheduleRows', () => {
  const rows = [
    mockRow({ farmId: 1, fieldId: 1, fieldCultivationId: 101, farmName: 'Farm A', fieldName: 'Field 1' }),
    mockRow({ farmId: 1, fieldId: 2, fieldCultivationId: 102, farmName: 'Farm A', fieldName: 'Field 2' }),
    mockRow({ farmId: 2, fieldId: 3, fieldCultivationId: 201, farmName: 'Farm B', fieldName: 'Field 3' })
  ];

  it('returns all rows when field filter is null', () => {
    expect(filterPlanTaskScheduleRows(rows, null, null)).toHaveLength(3);
  });

  it('filters by field cultivation id', () => {
    const filtered = filterPlanTaskScheduleRows(rows, null, 102);
    expect(filtered).toHaveLength(1);
    expect(filtered[0].fieldName).toBe('Field 2');
  });
});

describe('filterCrossFarmScheduleRowsFromDate', () => {
  const rows = [
    mockRow({
      farmId: 1,
      fieldCultivationId: 101,
      item: { item_id: 1, name: 'Early', scheduled_date: '2026-06-01' } as CrossFarmScheduleRow['item']
    }),
    mockRow({
      farmId: 1,
      fieldCultivationId: 102,
      item: { item_id: 2, name: 'On boundary', scheduled_date: '2026-06-10' } as CrossFarmScheduleRow['item']
    }),
    mockRow({
      farmId: 2,
      fieldCultivationId: 201,
      item: { item_id: 3, name: 'Later', scheduled_date: '2026-06-15' } as CrossFarmScheduleRow['item']
    })
  ];

  it('keeps rows with scheduled_date on or after fromDate', () => {
    const filtered = filterCrossFarmScheduleRowsFromDate(rows, '2026-06-10');

    expect(filtered.map((row) => row.item.name)).toEqual(['On boundary', 'Later']);
  });

  it('excludes rows without scheduled_date', () => {
    const withUnscheduled = [
      ...rows,
      mockRow({
        farmId: 1,
        fieldCultivationId: 103,
        item: { item_id: 4, name: 'Unscheduled', scheduled_date: '' } as CrossFarmScheduleRow['item']
      })
    ];

    expect(filterCrossFarmScheduleRowsFromDate(withUnscheduled, '2026-01-01')).toHaveLength(3);
  });
});

describe('buildPlanTaskScheduleFieldFilterOptions', () => {
  const rows = [
    mockRow({ farmId: 1, fieldId: 1, fieldCultivationId: 101, farmName: 'Farm A', fieldName: 'Field 1' }),
    mockRow({ farmId: 1, fieldId: 2, fieldCultivationId: 102, farmName: 'Farm A', fieldName: 'Field 2' }),
    mockRow({ farmId: 2, fieldId: 3, fieldCultivationId: 201, farmName: 'Farm B', fieldName: 'Field 3' })
  ];

  it('builds unique field options sorted by label', () => {
    const options = buildPlanTaskScheduleFieldFilterOptions(rows);
    expect(options.map((field) => field.label)).toEqual(['Field 1', 'Field 2', 'Field 3']);
    expect(options.map((field) => field.value)).toEqual([1, 2, 3]);
  });

  it('deduplicates multiple cultivations on the same plan field', () => {
    const duplicatedRows = [
      mockRow({ farmId: 1, fieldId: 1, fieldCultivationId: 101, fieldName: '1' }),
      mockRow({ farmId: 1, fieldId: 1, fieldCultivationId: 102, fieldName: '1' }),
      mockRow({ farmId: 1, fieldId: 1, fieldCultivationId: 103, fieldName: '1' }),
      mockRow({ farmId: 1, fieldId: 2, fieldCultivationId: 201, fieldName: '2' }),
      mockRow({ farmId: 1, fieldId: 2, fieldCultivationId: 202, fieldName: '2' }),
      mockRow({ farmId: 1, fieldId: 2, fieldCultivationId: 203, fieldName: '2' })
    ];

    const options = buildPlanTaskScheduleFieldFilterOptions(duplicatedRows);

    expect(options).toEqual([
      { value: 1, label: '1' },
      { value: 2, label: '2' }
    ]);
  });
});

describe('filterPlanTaskScheduleRows by plan field', () => {
  const rows = [
    mockRow({ farmId: 1, fieldId: 1, fieldCultivationId: 101, fieldName: '1' }),
    mockRow({ farmId: 1, fieldId: 1, fieldCultivationId: 102, fieldName: '1' }),
    mockRow({ farmId: 1, fieldId: 2, fieldCultivationId: 201, fieldName: '2' })
  ];

  it('filters all cultivations on the selected plan field', () => {
    const filtered = filterPlanTaskScheduleRows(rows, 1, null);
    expect(filtered).toHaveLength(2);
    expect(filtered.every((row) => row.fieldId === 1)).toBe(true);
  });

  it('filters by field cultivation id when deep-linked', () => {
    const filtered = filterPlanTaskScheduleRows(rows, null, 201);
    expect(filtered).toHaveLength(1);
    expect(filtered[0].fieldCultivationId).toBe(201);
  });
});
