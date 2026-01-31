export interface CreatePrivatePlanInputDto {
  farmId: number;
  planName?: string;
  cropIds: number[];
}

export interface CreatePrivatePlanResponseDto {
  id: number;
}