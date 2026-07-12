import { FieldSchedule, PlanInfo } from '../../models/plans/task-schedule';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import { WorkRecordSheetSavedEvent } from './work-record-sheet.view';

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
  nextScheduled: WorkDayListRowDto | null;
  highlightedItemId: number | null;
  completingItemId: number | null;
  regenerating: boolean;
  regenerateError: string | null;
  pendingSyncToastKey: string | null;
  pendingRecordSavedToastKey: string | null;
  pendingRecordSavedEvent: WorkRecordSheetSavedEvent | null;
  pendingQuickCompleteValidation: {
    itemId: number;
    fieldErrors: Record<string, string[]>;
  } | null;
  syncReloadNonce: number;
  cropIdsForBanner: number[];
  cropNamesForBanner: Record<number, string>;
}

export interface PlanWorkView {
  control: PlanWorkViewState;
}
