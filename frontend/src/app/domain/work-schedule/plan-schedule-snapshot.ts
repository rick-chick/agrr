/** Detail fields for the task schedule item detail panel. */
export interface PlanTaskScheduleItemDetails {
  stageName: string | null;
  amount: string | null;
  amountUnit: string | null;
  masterDescription: string | null;
}

export const emptyPlanTaskScheduleItemDetails: PlanTaskScheduleItemDetails = {
  stageName: null,
  amount: null,
  amountUnit: null,
  masterDescription: null
};

export const emptyPlanTaskScheduleItemVariance = {
  actualDate: null,
  deltaDays: null,
  gddTrigger: null,
  gddAtActual: null,
  gddDelta: null
} as const;

/** Task row fields used by flatten / filter / group and month-list display. */
export interface PlanTaskScheduleItem {
  item_id: number;
  name: string;
  scheduled_date: string | null;
  actualDate: string | null;
  deltaDays: number | null;
  gddTrigger: number | null;
  gddAtActual: number | null;
  gddDelta: number | null;
  stageOrder?: number | null;
  category?: string;
  status: string;
  /** Derived from linked work_records in timeline API; not from legacy status column. */
  completed: boolean;
  details: PlanTaskScheduleItemDetails;
}

export interface PlanFieldSchedule {
  id: number;
  name: string;
  crop_name: string;
  crop_id?: number;
  field_cultivation_id: number;
  schedules: {
    general: ReadonlyArray<PlanTaskScheduleItem>;
    fertilizer: ReadonlyArray<PlanTaskScheduleItem>;
    unscheduled: ReadonlyArray<PlanTaskScheduleItem>;
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
