import type { FieldCultivationClimateData, StageRequirement } from './field-cultivation-climate-data';

function weatherMinForDate(
  climate: FieldCultivationClimateData,
  date: string
): number | null {
  const row = climate.weather_data.find((datum) => datum.date === date);
  if (row?.temperature_min == null) {
    return null;
  }
  return row.temperature_min;
}

function cumulativeGddForDate(
  climate: FieldCultivationClimateData,
  date: string
): number | null {
  let last: number | null = null;
  for (const datum of climate.gdd_data) {
    if (datum.date > date) {
      break;
    }
    if (datum.cumulative_gdd != null) {
      last = datum.cumulative_gdd;
    }
    if (datum.date === date) {
      return last;
    }
  }
  return last;
}

function activeStageForDate(
  climate: FieldCultivationClimateData,
  date: string
): StageRequirement | null {
  const cumulative = cumulativeGddForDate(climate, date);
  if (cumulative == null || climate.stages.length === 0) {
    return climate.stages[0] ?? null;
  }

  const sorted = [...climate.stages].sort((a, b) => a.order - b.order);
  let active: StageRequirement | null = sorted[0] ?? null;
  for (const stage of sorted) {
    if (cumulative >= stage.cumulative_gdd_required) {
      active = stage;
    }
  }
  return active;
}

function resolveFrostThreshold(
  climate: FieldCultivationClimateData,
  date: string
): number | null {
  const stage = activeStageForDate(climate, date);
  if (stage?.frost_threshold != null) {
    return stage.frost_threshold;
  }
  if (stage?.low_stress_threshold != null) {
    return stage.low_stress_threshold;
  }
  return climate.crop_requirements.optimal_temperature_range?.low_stress ?? null;
}

export function detectFieldFrostRiskForDate(
  climate: FieldCultivationClimateData,
  date: string
): boolean {
  const minTemp = weatherMinForDate(climate, date);
  const threshold = resolveFrostThreshold(climate, date);
  if (minTemp == null || threshold == null) {
    return false;
  }
  return minTemp < threshold;
}

export function countPlanFrostRisks(
  climates: FieldCultivationClimateData[],
  date: string
): number {
  return climates.filter((climate) => detectFieldFrostRiskForDate(climate, date)).length;
}
