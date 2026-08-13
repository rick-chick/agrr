import { TaskScheduleItemUpdateRequest } from '../../models/plans/task-schedule';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateTaskScheduleItemInputDto {
  planId: number;
  itemId: number;
  body: TaskScheduleItemUpdateRequest;
  onSuccess?: () => void;
  onError?: (dto: ErrorDto) => void;
}
