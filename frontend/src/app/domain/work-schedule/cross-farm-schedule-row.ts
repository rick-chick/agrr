import type { PlanTaskScheduleItem } from './plan-schedule-snapshot';

export interface CrossFarmScheduleRow {
  item: PlanTaskScheduleItem;
  farmId: number;
  farmName: string;
  planId: number;
  planName: string;
  fieldId: number;
  fieldName: string;
  fieldCultivationId: number;
  cropName: string;
}

export interface CrossFarmScheduleSource {
  farmId: number;
  farmName: string;
  planId: number;
  planName: string;
  fields: ReadonlyArray<{
    id: number;
    name: string;
    crop_name: string;
    field_cultivation_id: number;
    schedules: {
      general: ReadonlyArray<PlanTaskScheduleItem>;
      fertilizer: ReadonlyArray<PlanTaskScheduleItem>;
    };
  }>;
}

export interface CrossFarmScheduleFilterOption {
  value: number;
  label: string;
}
