import { FieldSchedule, PlanInfo, TaskScheduleItem } from '../../models/plans/task-schedule';

export interface WorkDayListRowDto {
  item: TaskScheduleItem;
  fieldName: string;
  cropName: string;
  recordedToday: boolean;
  /** Days past scheduled_date when grouped as overdue (local today basis). */
  overdueDays?: number;
}

export interface LoadWorkDayListInputDto {
  planId: number;
  today: string;
  includeSkipped?: boolean;
  loadGeneration?: number;
}

export interface RecentAdHocRecordDto {
  name: string;
  actualDate: string;
}

export interface LoadWorkDayListDataDto {
  plan: PlanInfo;
  fields: FieldSchedule[];
  overdue: WorkDayListRowDto[];
  today: WorkDayListRowDto[];
  upcoming: WorkDayListRowDto[];
  recentAdHocRecord: RecentAdHocRecordDto | null;
  nextScheduled: WorkDayListRowDto | null;
  loadGeneration?: number;
}
