import { PlanWorkViewState } from './plan-work.view';
import { WorkRecordSheetSavedEvent } from './work-record-sheet.view';

export type PlanWorkRecordSavedViewPatch = Pick<
  PlanWorkViewState,
  'recentAdHocRecord' | 'highlightedItemId'
>;

export function planWorkRecordSavedPatch(
  event: WorkRecordSheetSavedEvent
): PlanWorkRecordSavedViewPatch {
  if (event.mode === 'create-adhoc') {
    return {
      recentAdHocRecord: {
        name: event.workRecord.name,
        actualDate: event.workRecord.actual_date
      },
      highlightedItemId: null
    };
  }

  if (event.mode === 'create-from-item' && event.workRecord.task_schedule_item_id != null) {
    return {
      recentAdHocRecord: null,
      highlightedItemId: event.workRecord.task_schedule_item_id
    };
  }

  return {
    recentAdHocRecord: null,
    highlightedItemId: null
  };
}
