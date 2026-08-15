import { FieldSchedule, PlanInfo } from '../../models/plans/task-schedule';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import { PendingToastRequest } from '../../core/view-effects/pending-toast-view.effects';
import type { PlanSaveImpactViewFields } from '../../adapters/plans/plan-save-impact.presenter.helpers';
import type { PlanWorkVarianceSummaryStats } from '../../domain/plans/build-plan-work-variance-summary-stats';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';
import { WorkRecordSheetSavedEvent } from './work-record-sheet.view';
import type { WorkListSegment } from '../../domain/work-schedule/work-row-fertilizer';

export interface PlanWorkViewState extends PlanSaveImpactViewFields {
  loading: boolean;
  error: string | null;
  plan: PlanInfo | null;
  fields: FieldSchedule[];
  overdue: WorkDayListRowDto[];
  today: WorkDayListRowDto[];
  upcoming: WorkDayListRowDto[];
  includeSkipped: boolean;
  workSegment: WorkListSegment;
  recentAdHocRecord: { name: string; actualDate: string } | null;
  nextScheduled: WorkDayListRowDto | null;
  highlightedItemId: number | null;
  completingItemId: number | null;
  regenerating: boolean;
  regenerateError: string | null;
  pendingSyncToastKey: string | null;
  pendingRecordSavedToast: PendingToastRequest | null;
  pendingRecordSavedEvent: WorkRecordSheetSavedEvent | null;
  pendingQuickCompleteValidation: {
    itemId: number;
    fieldErrors: Record<string, string[]>;
  } | null;
  syncReloadNonce: number;
  cropIdsForBanner: number[];
  cropNamesForBanner: Record<number, string>;
  varianceSummaryLoading: boolean;
  varianceSummaryError: string | null;
  varianceSummaryStats: PlanWorkVarianceSummaryStats | null;
  actionRequiredItems: PlanVarianceActionItem[];
}

export interface PlanWorkView {
  control: PlanWorkViewState;
}
