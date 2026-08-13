import { WorkRecord } from '../../models/plans/work-record';
import type { PlanVsActualPlanSummaryStats } from './plan-vs-actual-summary';
import {
  formatVarianceDeltaDays,
  formatVarianceGddDelta,
  parseGddTrigger,
  workRecordDeltaDays,
  workRecordGddDelta
} from './work-record-variance';
import { findVarianceActionItemForRecord } from './find-variance-action-item-for-record';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';
import { WorkRecordSaveMode, WorkRecordSaveToastContext } from './work-record-save-toast';

export type WorkRecordSaveImpactViewModel = {
  taskName: string;
  deltaDays: string | null;
  gddDelta: string | null;
  planStats: PlanVsActualPlanSummaryStats;
  workbenchFieldCultivationId: number | null;
};

export function buildWorkRecordSaveImpact(
  record: WorkRecord,
  mode: WorkRecordSaveMode,
  planStats: PlanVsActualPlanSummaryStats,
  context?: WorkRecordSaveToastContext | null,
  actionRequiredItems: ReadonlyArray<PlanVarianceActionItem> = []
): WorkRecordSaveImpactViewModel | null {
  if (mode === 'edit') {
    return null;
  }

  let deltaDays: string | null = null;
  let gddDelta: string | null = null;

  if (mode === 'create-from-item' && record.task_schedule_item_id != null) {
    const days = workRecordDeltaDays(record);
    const gdd = workRecordGddDelta(record, parseGddTrigger(context?.gddTrigger ?? null));
    deltaDays = days != null ? formatVarianceDeltaDays(days) : null;
    gddDelta = gdd != null ? formatVarianceGddDelta(gdd) : null;
  }

  const actionItem = findVarianceActionItemForRecord(record, actionRequiredItems);

  return {
    taskName: record.name,
    deltaDays,
    gddDelta,
    planStats,
    workbenchFieldCultivationId: actionItem?.field_cultivation_id ?? null
  };
}
