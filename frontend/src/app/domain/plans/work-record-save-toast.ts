import { WorkRecord } from '../../models/plans/work-record';
import {
  formatVarianceDeltaDays,
  formatVarianceGddDelta,
  parseGddTrigger,
  workRecordDeltaDays,
  workRecordGddDelta
} from './work-record-variance';

export type WorkRecordSaveMode = 'create-from-item' | 'create-adhoc' | 'edit';

export type WorkRecordSaveToastContext = {
  planId: number;
  fieldCultivationId: number;
  taskScheduleItemId: number;
  gddTrigger?: string | number | null;
};

export type WorkRecordSaveToastResult = {
  textKey: string;
  textParams?: Record<string, string | number>;
  navigation?: {
    planId: number;
    fieldCultivationId: number;
    taskScheduleItemId: number;
  };
};

export function buildWorkRecordSaveToast(
  record: WorkRecord,
  mode: WorkRecordSaveMode,
  context?: WorkRecordSaveToastContext | null
): WorkRecordSaveToastResult {
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
    navigation: {
      planId: context.planId,
      fieldCultivationId: context.fieldCultivationId,
      taskScheduleItemId: context.taskScheduleItemId
    }
  };
}
