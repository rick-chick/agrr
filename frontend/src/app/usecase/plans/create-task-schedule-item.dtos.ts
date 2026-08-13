export interface CreateTaskScheduleItemInputDto {
  planId: number;
  fieldCultivationId: number;
  name: string;
  scheduledDate: string;
  agriculturalTaskId?: number | null;
  onSuccess?: () => void;
  onError?: () => void;
}
