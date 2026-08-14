import type { ClimateTemperaturePoint } from './field-cultivation-climate-data';

export type WorkRecordWeatherSnapshotSummary = {
  max: number | null;
  min: number | null;
  mean: number | null;
};

export function workRecordWeatherSnapshotSummary(
  snapshot: ClimateTemperaturePoint | null | undefined
): WorkRecordWeatherSnapshotSummary | null {
  if (!snapshot || typeof snapshot !== 'object') {
    return null;
  }

  const hasDate = typeof snapshot.date === 'string' && snapshot.date.trim().length > 0;
  const hasTemperature =
    snapshot.temperature_max != null ||
    snapshot.temperature_min != null ||
    snapshot.temperature_mean != null;

  if (!hasDate && !hasTemperature) {
    return null;
  }

  return {
    max: snapshot.temperature_max ?? null,
    min: snapshot.temperature_min ?? null,
    mean: snapshot.temperature_mean ?? null
  };
}
