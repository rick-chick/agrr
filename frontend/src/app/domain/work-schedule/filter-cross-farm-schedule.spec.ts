import { describe, expect, it } from 'vitest';
import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';
import {
  buildCrossFarmScheduleFilterOptions,
  filterCrossFarmScheduleRows,
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
    fieldName: 'Field 1',
    cropName: 'Tomato',
    ...overrides
  };
}

describe('filterCrossFarmScheduleRows', () => {
  const rows = [
    mockRow({ farmId: 1, fieldCultivationId: 101, farmName: 'Farm A', fieldName: 'Field 1' }),
    mockRow({ farmId: 1, fieldCultivationId: 102, farmName: 'Farm A', fieldName: 'Field 2' }),
    mockRow({ farmId: 2, fieldCultivationId: 201, farmName: 'Farm B', fieldName: 'Field 3' })
  ];

  it('returns all rows when filters are empty', () => {
    expect(filterCrossFarmScheduleRows(rows, { farmId: null, fieldCultivationId: null })).toHaveLength(3);
  });

  it('filters by farm', () => {
    const filtered = filterCrossFarmScheduleRows(rows, { farmId: 2, fieldCultivationId: null });
    expect(filtered).toHaveLength(1);
    expect(filtered[0].farmName).toBe('Farm B');
  });

  it('filters by field within farm context', () => {
    const filtered = filterCrossFarmScheduleRows(rows, {
      farmId: 1,
      fieldCultivationId: 102
    });
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

describe('buildCrossFarmScheduleFilterOptions', () => {
  const rows = [
    mockRow({ farmId: 1, fieldCultivationId: 101, farmName: 'Farm A', fieldName: 'Field 1' }),
    mockRow({ farmId: 2, fieldCultivationId: 201, farmName: 'Farm B', fieldName: 'Field 3' })
  ];

  it('builds unique farm options', () => {
    const options = buildCrossFarmScheduleFilterOptions(rows, null);
    expect(options.farms.map((farm) => farm.label)).toEqual(['Farm A', 'Farm B']);
  });

  it('builds field options for selected farm only', () => {
    const options = buildCrossFarmScheduleFilterOptions(rows, 1);
    expect(options.fields.map((field) => field.label)).toEqual(['Field 1']);
  });
});
