/** Task row fields used by flatten / filter / group and month-list display. */
export interface PlanTaskScheduleItem {
  item_id: number;
  name: string;
  scheduled_date: string | null;
  status: string;
}

export interface PlanFieldSchedule {
  name: string;
  crop_name: string;
  field_cultivation_id: number;
  schedules: {
    general: ReadonlyArray<PlanTaskScheduleItem>;
    fertilizer: ReadonlyArray<PlanTaskScheduleItem>;
  };
}

export interface PlanSchedulePlanInfo {
  id: number;
  name: string;
}

export interface PlanScheduleSnapshot {
  plan: PlanSchedulePlanInfo;
  fields: ReadonlyArray<PlanFieldSchedule>;
}
