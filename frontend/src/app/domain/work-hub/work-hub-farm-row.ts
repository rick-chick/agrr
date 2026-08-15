export interface WorkHubFarmRow {
  farmId: number;
  farmName: string;
  fieldCount: number;
  totalArea: number;
  hasValidFields: boolean;
  planId: number | null;
  /** DB status of hub-selected representative plan (`completed` = active, `pending` = draft). */
  representativePlanStatus?: string | null;
  overdueCount: number;
  todayCount: number;
  gddDelayCount: number;
  thresholdExceededCount: number;
}
