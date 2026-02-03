export interface LoadFieldClimateInputDto {
  fieldCultivationId: number;
  planType: 'private' | 'public';
}

export interface FetchFieldClimateDataRequestDto {
  fieldCultivationId: number;
  planType: 'private' | 'public';
}
