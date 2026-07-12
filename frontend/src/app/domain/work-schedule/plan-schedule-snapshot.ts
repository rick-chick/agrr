/** Detail fields for the task schedule item detail panel. */
export interface PlanTaskScheduleItemDetails {
  stageName: string | null;
  gddTrigger: string | null;
  gddTolerance: string | null;
  amount: string | null;
  amountUnit: string | null;
  masterName: string | null;
  masterDescription: string | null;
}

export const emptyPlanTaskScheduleItemDetails: PlanTaskScheduleItemDetails = {
  stageName: null,
  gddTrigger: null,
  gddTolerance: null,
  amount: null,
  amountUnit: null,
  masterName: null,
  masterDescription: null
};

/** Task row fields used by flatten / filter / group and month-list display. */
export interface PlanTaskScheduleItem {
  item_id: number;
  name: string;
  scheduled_date: string | null;
  status: string;
  details: PlanTaskScheduleItemDetails;
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
