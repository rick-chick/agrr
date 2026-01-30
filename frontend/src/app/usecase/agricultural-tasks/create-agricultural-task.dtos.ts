import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';

export interface CreateAgriculturalTaskInputDto {
  name: string;
  description?: string | null;
  time_per_sqm?: number | null;
  weather_dependency?: 'low' | 'medium' | 'high' | string;
  required_tools: string[];
  skill_level?: 'beginner' | 'intermediate' | 'advanced' | string;
  region?: string | null;
  task_type?: string | null;
  onSuccess?: (agriculturalTask: AgriculturalTask) => void;
}

export interface CreateAgriculturalTaskSuccessDto {
  agriculturalTask: AgriculturalTask;
}