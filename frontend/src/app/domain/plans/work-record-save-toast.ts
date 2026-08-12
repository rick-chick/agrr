import { WorkRecord } from '../../models/plans/work-record';
import { PendingToastRequest } from '../../core/view-effects/pending-toast-view.effects';
import { WorkRecordSheetMode } from '../../components/plans/work-record-sheet.view';
import {
  formatVarianceDeltaDays,
  formatVarianceGddDelta,
  parseGddTrigger,
  workRecordDeltaDays,
  workRecordGddDelta
} from './work-record-variance';

export type WorkRecordSaveToastContext = {
  planId: number;
  fieldCultivationId: number;
  taskScheduleItemId: number;
  gddTrigger?: string | number | null;
};

export function buildWorkRecordSaveToast(
  record: WorkRecord,
  mode: WorkRecordSheetMode,
  context?: WorkRecordSaveToastContext | null
): PendingToastRequest {
  if (mode === 'edit') {
    return { textKey: 'plans.work_records.toast.record_updated' };
  }
  if (mode === 'create-adhoc' || record.task_schedule_item_id == null) {
    return { textKey: 'plans.work.toast.record_saved_adhoc' };
  }

  const deltaDays = workRecordDeltaDays(record);
  const gddDelta = workRecordGddDelta(record, parseGddTrigger(context?.gddTrigger ?? null));
  const hasVariance = deltaDays != null || gddDelta != null;

  if (!hasVariance || context == null) {
    return { textKey: 'plans.work.toast.record_saved' };
  }

  return {
    textKey: 'plans.work.toast.record_saved_variance',
    textParams: {
      name: record.name,
      deltaDays: deltaDays != null ? formatVarianceDeltaDays(deltaDays) : '—',
      gddDelta: gddDelta != null ? formatVarianceGddDelta(gddDelta) : '—'
    },
    action: {
      labelKey: 'plans.work.toast.view_task_detail',
      routerLink: ['/plans', context.planId, 'task_schedule'],
      queryParams: {
        field_cultivation_id: context.fieldCultivationId,
        item_id: context.taskScheduleItemId
      }
    }
  };
}
