export interface RetryFarmWeatherFetchInputDto {
  farmId: number;
  onSettled?: () => void;
}
