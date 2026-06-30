export interface WorkHubFarmRow {
  farmId: number;
  farmName: string;
  fieldCount: number;
  totalArea: number;
  hasValidFields: boolean;
  planId: number | null;
}
