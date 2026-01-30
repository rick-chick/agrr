export interface Field {
  id: number;
  farm_id: number;
  user_id: number | null;
  name: string;
  description: string | null;
  area: number | null;
  daily_fixed_cost: number | null;
  region: string | null;
  created_at: string;
  updated_at: string;
}

export interface Farm {
  id: number;
  name: string;
  latitude: number;
  longitude: number;
  region: string;
  description?: string | null;
  weather_data_status?: 'pending' | 'fetching' | 'completed' | 'failed';
  weather_data_progress?: number;
  weather_data_fetched_years?: number;
  weather_data_total_years?: number;
  is_reference?: boolean;
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
  crop_stages?: CropStage[];
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

export interface Fertilize {
  id: number;
  name: string;
  n?: number | null;
  p?: number | null;
  k?: number | null;
  description?: string | null;
  package_size?: number | null;
  is_reference: boolean;
  region?: string | null;
}

export interface Pest {
  id: number;
  name: string;
  name_scientific?: string | null;
  family?: string | null;
  order?: string | null;
  description?: string | null;
  occurrence_season?: string | null;
  is_reference: boolean;
  region?: string | null;
}

export interface Pesticide {
  id: number;
  name: string;
  active_ingredient?: string | null;
  description?: string | null;
  is_reference: boolean;
  crop_id: number;
  pest_id: number;
  region?: string | null;
}

export interface AgriculturalTask {
  id: number;
  name: string;
  description?: string | null;
  time_per_sqm?: number | null;
  weather_dependency?: 'low' | 'medium' | 'high' | string;
  required_tools: string[];
  skill_level?: 'beginner' | 'intermediate' | 'advanced' | string;
  is_reference: boolean;
  region?: string | null;
}

export interface InteractionRule {
  id: number;
  rule_type: string;
  source_group: string;
  target_group: string;
  impact_ratio: number;
  is_directional: boolean;
  description?: string | null;
  is_reference: boolean;
}
