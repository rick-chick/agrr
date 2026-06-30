import { FieldSchedule, PlanInfo } from '../../models/plans/task-schedule';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';

export interface PlanWorkViewState {
  loading: boolean;
  error: string | null;
  plan: PlanInfo | null;
  fields: FieldSchedule[];
  overdue: WorkDayListRowDto[];
  today: WorkDayListRowDto[];
  upcoming: WorkDayListRowDto[];
  includeSkipped: boolean;
  recentAdHocRecord: { name: string; actualDate: string } | null;
  highlightedItemId: number | null;
  completingItemId: number | null;
}

export interface PlanWorkView {
  control: PlanWorkViewState;
}
