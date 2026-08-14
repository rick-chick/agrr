export interface LoadPlanWorkFrostRiskInputDto {
  planId: number;
  fieldCultivationIds: number[];
  today: string;
  loadGeneration?: number;
}

export interface LoadPlanWorkFrostRiskDataDto {
  frostRiskCount: number;
  loadGeneration?: number;
}
