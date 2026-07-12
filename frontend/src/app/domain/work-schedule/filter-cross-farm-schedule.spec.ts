import { describe, expect, it } from 'vitest';
import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';
import {
  buildCrossFarmScheduleFilterOptions,
  filterCrossFarmScheduleRows
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
