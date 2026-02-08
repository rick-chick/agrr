export interface FieldData {
  id: number;
  field_id: number;
  name: string;
  area: number;
  daily_fixed_cost: number;
}

export interface CropData {
  id: number;
  name: string;
  area_per_unit: number;
  revenue_per_area: number;
}

export interface AvailableCropData {
  id: number;
  name: string;
  variety: string;
  area_per_unit: number;
}

export interface CultivationData {
  id: number;
  field_id: number;
  field_name: string;
  crop_id: number;
  crop_name: string;
  area: number;
  start_date: string;
  completion_date: string;
  cultivation_days: number;
  estimated_cost: number;
  revenue: number;
  profit: number;
  status: string;
}

export interface CultivationPlanData {
  success: boolean;
  data: {
    id: number;
    plan_year: number;
    plan_name: string;
    status: string;
    total_area: number;
    planning_start_date: string;
    planning_end_date: string;
    fields: FieldData[];
    crops: CropData[];
    available_crops?: AvailableCropData[];
    cultivations: CultivationData[];
  };
  total_profit: number;
  total_revenue: number;
  total_cost: number;
}
