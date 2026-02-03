export interface ClimateTemperaturePoint {
  date: string;
  temperature_max?: number;
  temperature_min?: number;
  temperature_mean?: number;
}

export interface ClimateGddPoint {
  date: string;
  gdd: number;
  cumulative_gdd: number;
  temperature?: number;
  current_stage?: string | null;
}

export interface OptimalTemperatureRange {
  min: number;
  max: number;
  low_stress: number;
  high_stress: number;
}

export interface CropRequirements {
  base_temperature: number;
  optimal_temperature_range?: OptimalTemperatureRange | null;
}

export interface StageRequirement {
  name: string;
  order: number;
  gdd_required: number;
  cumulative_gdd_required: number;
  optimal_temperature_min?: number;
  optimal_temperature_max?: number;
  low_stress_threshold?: number;
  high_stress_threshold?: number;
}

export interface FieldCultivationSummary {
  id: number;
  field_name: string;
  crop_name: string;
  start_date: string;
  completion_date: string;
}

export interface FarmSummary {
  id: number;
  name: string;
  latitude: number;
  longitude: number;
}

export interface FieldCultivationClimateData {
  success: boolean;
  field_cultivation: FieldCultivationSummary;
  farm: FarmSummary;
  crop_requirements: CropRequirements;
  weather_data: ClimateTemperaturePoint[];
  gdd_data: ClimateGddPoint[];
  stages: StageRequirement[];
  progress_result: Record<string, unknown>;
  debug_info: Record<string, unknown>;
}
