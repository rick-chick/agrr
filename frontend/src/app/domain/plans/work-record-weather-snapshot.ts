import { ClimateTemperaturePoint } from './field-cultivation-climate-data';
import { WorkRecord } from '../../models/plans/work-record';

export interface WorkRecordWeatherSnapshotSummary {
  temperatureMax: number | null;
  temperatureMin: number | null;
  temperatureMean: number | null;
}

export function workRecordWeatherSnapshotSummary(
  record: WorkRecord
): WorkRecordWeatherSnapshotSummary | null {
  const raw = record.weather_snapshot;
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const point = raw as ClimateTemperaturePoint;
  const hasTemperature =
    point.temperature_max != null ||
    point.temperature_min != null ||
    point.temperature_mean != null;
  if (!hasTemperature) {
    return null;
  }
  return {
    temperatureMax: point.temperature_max ?? null,
    temperatureMin: point.temperature_min ?? null,
    temperatureMean: point.temperature_mean ?? null
  };
}
