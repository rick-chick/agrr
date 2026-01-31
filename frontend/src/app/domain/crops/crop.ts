export interface TemperatureRequirement {
  id: number;
  base_temperature: number;
  optimal_min: number;
  optimal_max: number;
  low_stress: number;
  high_stress: number;
}

export interface ThermalRequirement {
  id: number;
  required_gdd: number;
}

export interface SunshineRequirement {
  id: number;
  minimum_hours: number;
  target_hours: number;
}

export interface NutrientRequirement {
  id: number;
  daily_uptake_n: number;
  daily_uptake_p: number;
  daily_uptake_k: number;
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
