/** Gantt mutation wire shapes at the usecase gateway boundary. */
export type GanttAddCropRequest = {
  crop_id: number;
  field_id?: number;
  display_start_date?: string;
  display_end_date?: string;
};

export type GanttAddFieldRequest = {
  field_name: string;
  field_area: number;
  daily_fixed_cost?: number;
};
