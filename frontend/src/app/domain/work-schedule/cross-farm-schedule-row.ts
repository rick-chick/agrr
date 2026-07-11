import type { TaskScheduleItem } from '../../models/plans/task-schedule';

export interface CrossFarmScheduleRow {
  item: TaskScheduleItem;
  farmId: number;
  farmName: string;
  planId: number;
  planName: string;
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
    name: string;
    crop_name: string;
    field_cultivation_id: number;
    schedules: {
      general: ReadonlyArray<TaskScheduleItem>;
      fertilizer: ReadonlyArray<TaskScheduleItem>;
    };
  }>;
}

export interface CrossFarmScheduleFilter {
  farmId: number | null;
  fieldCultivationId: number | null;
}

export interface CrossFarmScheduleFilterOption {
  value: number;
  label: string;
}
