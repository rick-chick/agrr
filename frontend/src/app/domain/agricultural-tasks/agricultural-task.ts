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
  task_type?: string | null;
}
