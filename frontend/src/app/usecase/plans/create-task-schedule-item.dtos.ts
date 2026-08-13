import { TaskScheduleItemCreateRequest } from '../../models/plans/task-schedule';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreateTaskScheduleItemInputDto {
  planId: number;
  body: TaskScheduleItemCreateRequest;
  onSuccess?: () => void;
  onError?: (dto: ErrorDto) => void;
}
