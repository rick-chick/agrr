export interface UpdateTaskScheduleItemInputDto {
  planId: number;
  itemId: number;
  scheduledDate: string;
  onSuccess?: () => void;
}
