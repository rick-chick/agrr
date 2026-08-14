import type { ClimateTemperaturePoint } from './field-cultivation-climate-data';

type WorkRecordWeatherSnapshotSummary = {
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

  const hasTemperature =
    snapshot.temperature_max != null ||
    snapshot.temperature_min != null ||
    snapshot.temperature_mean != null;

  if (!hasTemperature) {
    return null;
  }

  return {
    max: snapshot.temperature_max ?? null,
    min: snapshot.temperature_min ?? null,
    mean: snapshot.temperature_mean ?? null
  };
}
