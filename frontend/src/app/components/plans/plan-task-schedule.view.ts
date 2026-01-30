import { TaskScheduleResponse } from '../../models/plans/task-schedule';

export type PlanTaskScheduleViewState = {
  loading: boolean;
  error: string | null;
  schedule: TaskScheduleResponse | null;
};

export interface PlanTaskScheduleView {
  get control(): PlanTaskScheduleViewState;
  set control(value: PlanTaskScheduleViewState);
}
