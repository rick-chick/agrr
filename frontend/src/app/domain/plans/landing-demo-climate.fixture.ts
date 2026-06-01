import { CultivationData } from './cultivation-plan-data';
import { FieldCultivationClimateData } from './field-cultivation-climate-data';
import { LandingDemoLabels, LANDING_DEMO_LABELS_FIXTURE } from './landing-demo-i18n.keys';

function buildDailySeries(
  startIso: string,
  dayCount: number,
  baseTemp: number,
  labels: LandingDemoLabels
): { weather: FieldCultivationClimateData['weather_data']; gdd: FieldCultivationClimateData['gdd_data'] } {
  const weather: FieldCultivationClimateData['weather_data'] = [];
  const gdd: FieldCultivationClimateData['gdd_data'] = [];
  const start = new Date(startIso);
  let cumulative = 0;
  for (let i = 0; i < dayCount; i++) {
    const d = new Date(start);
    d.setDate(d.getDate() + i);
    const iso = d.toISOString().split('T')[0]!;
    const wave = Math.sin((i / dayCount) * Math.PI * 2) * 6;
    const mean = baseTemp + wave;
    const min = mean - 4;
    const max = mean + 5;
    const dailyGdd = Math.max(0, mean - 10);
    cumulative += dailyGdd;
    weather.push({
      date: iso,
      temperature_min: Math.round(min * 10) / 10,
      temperature_mean: Math.round(mean * 10) / 10,
      temperature_max: Math.round(max * 10) / 10
    });
    gdd.push({
      date: iso,
      gdd: Math.round(dailyGdd * 10) / 10,
      cumulative_gdd: Math.round(cumulative * 10) / 10,
      temperature: Math.round(mean * 10) / 10,
      current_stage:
        cumulative < 400 ? labels.gddStageGrowing : labels.gddStagePreHarvest
    });
  }
  return { weather, gdd };
}

function climateForCultivation(
  input: {
    id: number;
    cropName: string;
    fieldName: string;
    startDate: string;
    completionDate: string;
    baseTemp: number;
  },
  labels: LandingDemoLabels
): FieldCultivationClimateData {
  const { weather, gdd } = buildDailySeries(input.startDate, 120, input.baseTemp, labels);
  return {
    success: true,
    field_cultivation: {
      id: input.id,
      field_name: input.fieldName,
      crop_name: input.cropName,
      start_date: input.startDate,
      completion_date: input.completionDate
    },
    farm: {
      id: 1,
      name: labels.farmName,
      latitude: 35.68,
      longitude: 139.77
    },
    crop_requirements: {
      base_temperature: 10,
      optimal_temperature_range: {
        min: 15,
        max: 28,
        low_stress: 8,
        high_stress: 32
      }
    },
    weather_data: weather,
    gdd_data: gdd,
    stages: [
      {
        name: labels.stageGermination,
        order: 1,
        gdd_required: 120,
        cumulative_gdd_required: 120,
        optimal_temperature_min: 15,
        optimal_temperature_max: 25
      },
      {
        name: labels.stageGrowth,
        order: 2,
        gdd_required: 350,
        cumulative_gdd_required: 470,
        optimal_temperature_min: 18,
        optimal_temperature_max: 28
      },
      {
        name: labels.stageHarvest,
        order: 3,
        gdd_required: 200,
        cumulative_gdd_required: 670,
        optimal_temperature_min: 16,
        optimal_temperature_max: 26
      }
    ]
  };
}

export function buildLandingDemoClimateForCultivation(
  cultivation: CultivationData,
  labels: LandingDemoLabels = LANDING_DEMO_LABELS_FIXTURE
): FieldCultivationClimateData {
  return climateForCultivation(
    {
      id: cultivation.id,
      cropName: cultivation.crop_name,
      fieldName: cultivation.field_name,
      startDate: cultivation.start_date,
      completionDate: cultivation.completion_date,
      baseTemp: 20 + (cultivation.id % 5)
    },
    labels
  );
}
