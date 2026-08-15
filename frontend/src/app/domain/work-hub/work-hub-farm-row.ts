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
}
