export type GanttAddCropHttpResponse = {
  success: boolean;
  message?: string;
  technical_details?: string;
  crop?: {
    id: number;
    name: string;
  };
};

export type GanttRemoveCultivationHttpResponse = {
  success: boolean;
  message?: string;
};

export type GanttAddFieldHttpResponse = {
  success: boolean;
  message?: string;
  field: {
    id: number;
    field_id: number;
    name: string;
    area: number;
  };
  total_area: number;
};

export type GanttRemoveFieldHttpResponse = {
  success: boolean;
  message?: string;
  field_id: number;
  total_area: number;
};

export type GanttAdjustPlanHttpResponse = {
  success: boolean;
  message?: string;
};
