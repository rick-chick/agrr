export interface TemperatureRequirement {
  id: number;
  crop_stage_id: number;
  base_temperature?: number | null;
  optimal_min?: number | null;
  optimal_max?: number | null;
  low_stress_threshold?: number | null;
  high_stress_threshold?: number | null;
  frost_threshold?: number | null;
  sterility_risk_threshold?: number | null;
  max_temperature?: number | null;
}

export interface ThermalRequirement {
  id: number;
  crop_stage_id: number;
  required_gdd?: number | null;
}

export interface SunshineRequirement {
  id: number;
  crop_stage_id: number;
  minimum_sunshine_hours?: number | null;
  target_sunshine_hours?: number | null;
}

export interface NutrientRequirement {
  id: number;
  crop_stage_id: number;
  daily_uptake_n?: number | null;
  daily_uptake_p?: number | null;
  daily_uptake_k?: number | null;
  region?: string | null;
}

export interface CropStage {
  id: number;
  crop_id: number;
  name: string;
  order: number;
  temperature_requirement?: TemperatureRequirement;
  thermal_requirement?: ThermalRequirement;
  sunshine_requirement?: SunshineRequirement;
  nutrient_requirement?: NutrientRequirement;
}

export interface Crop {
  id: number;
  name: string;
  variety?: string | null;
  is_reference: boolean;
  area_per_unit?: number | null;
  revenue_per_area?: number | null;
  groups: string[];
  region?: string | null;
  created_at?: string;
  updated_at?: string;
  crop_stages?: CropStage[];
}
