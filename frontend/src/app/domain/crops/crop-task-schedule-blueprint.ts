export interface CropTaskScheduleBlueprintRelatedTask {
  id: number;
  name: string;
  description?: string | null;
  is_reference?: boolean;
}

export interface CropTaskScheduleBlueprint {
  id: number;
  crop_id: number;
  agricultural_task_id: number | null;
  source_agricultural_task_id: number | null;
  stage_order: number;
  stage_name: string | null;
  gdd_trigger: number;
  gdd_tolerance: number | null;
  task_type: string;
  source: string;
  priority: number;
  amount: number | null;
  amount_unit: string | null;
  description: string | null;
  weather_dependency: string | null;
  time_per_sqm: number | null;
  name?: string | null;
  agricultural_task?: CropTaskScheduleBlueprintRelatedTask | null;
  created_at?: string | null;
  updated_at?: string | null;
}
