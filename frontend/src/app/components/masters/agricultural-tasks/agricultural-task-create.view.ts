export type AgriculturalTaskCreateFormData = {
  name: string;
  description?: string | null;
  time_per_sqm?: number | null;
  weather_dependency?: 'low' | 'medium' | 'high' | string | null;
  required_tools: string[];
  skill_level?: 'beginner' | 'intermediate' | 'advanced' | string | null;
  region?: string | null;
  task_type?: string | null;
};

export type AgriculturalTaskCreateViewState = {
  saving: boolean;
  error: string | null;
  formData: AgriculturalTaskCreateFormData;
};

export interface AgriculturalTaskCreateView {
  get control(): AgriculturalTaskCreateViewState;
  set control(value: AgriculturalTaskCreateViewState);
}