export interface SkipTaskScheduleItemInputDto {
  planId: number;
  itemId: number;
  skip: boolean;
  onSuccess?: () => void;
}
