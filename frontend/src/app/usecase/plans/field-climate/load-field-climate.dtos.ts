export interface LoadFieldClimateInputDto {
  fieldCultivationId: number;
  planType: 'private' | 'public';
  displayStartDate?: string | null;
  displayEndDate?: string | null;
}

export interface FetchFieldClimateDataRequestDto {
  fieldCultivationId: number;
  planType: 'private' | 'public';
  displayStartDate?: string | null;
  displayEndDate?: string | null;
}
