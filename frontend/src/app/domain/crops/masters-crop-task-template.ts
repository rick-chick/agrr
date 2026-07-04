export interface MastersCropTaskTemplateAgriculturalTask {
  id: number;
  name: string;
  description?: string | null;
  is_reference: boolean;
}

export interface MastersCropTaskTemplate {
  id: number;
  crop_id: number;
  agricultural_task_id: number;
  name: string;
  description?: string | null;
  time_per_sqm?: number | null;
  weather_dependency?: string | null;
  required_tools: string[];
  skill_level?: string | null;
  agricultural_task: MastersCropTaskTemplateAgriculturalTask;
  created_at?: string | null;
  updated_at?: string | null;
}
