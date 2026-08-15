export interface WorkHubFarmRow {
  farmId: number;
  farmName: string;
  fieldCount: number;
  totalArea: number;
  hasValidFields: boolean;
  planId: number | null;
  overdueCount: number;
  todayCount: number;
  unrecordedCount: number;
  gddDelayCount: number;
  daysExceedanceCount: number;
  thresholdExceededCount: number;
  otherVariancePlanCount: number;
}

export type WorkHubListedFarm = Omit<
  WorkHubFarmRow,
  | 'overdueCount'
  | 'todayCount'
  | 'unrecordedCount'
  | 'gddDelayCount'
  | 'daysExceedanceCount'
  | 'thresholdExceededCount'
  | 'otherVariancePlanCount'
>;
