import { describe, expect, it } from 'vitest';
import { WorkRecord } from '../../models/plans/work-record';
import { workRecordWeatherSnapshotSummary } from './work-record-weather-snapshot';

function baseRecord(overrides: Partial<WorkRecord> = {}): WorkRecord {
  return {
    id: 1,
    cultivation_plan_id: 7,
    field_cultivation_id: 10,
    task_schedule_item_id: 5,
    agricultural_task_id: null,
    name: 'Weeding',
    task_type: null,
    actual_date: '2026-06-12',
    amount: null,
    amount_unit: null,
    time_spent_minutes: null,
    notes: null,
    created_at: '2026-06-12',
    updated_at: '2026-06-12',
    task_schedule_item: null,
    ...overrides
  };
}

describe('workRecordWeatherSnapshotSummary', () => {
  it('returns temperature summary when weather_snapshot has values', () => {
    const summary = workRecordWeatherSnapshotSummary(
      baseRecord({
        weather_snapshot: {
          date: '2026-06-12',
          temperature_max: 25,
          temperature_min: 15,
          temperature_mean: 20
        }
      })
    );

    expect(summary).toEqual({
      temperatureMax: 25,
      temperatureMin: 15,
      temperatureMean: 20
    });
  });

  it('returns null when weather_snapshot is missing', () => {
    expect(workRecordWeatherSnapshotSummary(baseRecord())).toBeNull();
  });

  it('returns null when weather_snapshot has no temperature fields', () => {
    expect(
      workRecordWeatherSnapshotSummary(
        baseRecord({
          weather_snapshot: { date: '2026-06-12' }
        })
      )
    ).toBeNull();
  });
});
