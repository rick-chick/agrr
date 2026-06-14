import { FieldSchedule, PlanInfo, TaskScheduleItem } from '../../models/plans/task-schedule';

export interface WorkDayListRowDto {
  item: TaskScheduleItem;
  fieldName: string;
  cropName: string;
  recordedToday: boolean;
}

export interface LoadWorkDayListInputDto {
  planId: number;
  today: string;
  includeSkipped?: boolean;
}

export interface LoadWorkDayListDataDto {
  plan: PlanInfo;
  fields: FieldSchedule[];
  overdue: WorkDayListRowDto[];
  today: WorkDayListRowDto[];
  upcoming: WorkDayListRowDto[];
}
