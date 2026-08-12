import { WorkRecord } from '../../models/plans/work-record';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../work-schedule/format-plan-task-schedule-delta-days';
import type { WorkRecordSaveMode } from './work-record-save-toast';
import { buildPlanVsActualPlanSummaryStats } from './build-plan-vs-actual-plan-summary';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';
import {
  formatVarianceDeltaDays,
  formatVarianceGddDelta,
  parseGddTrigger,
  workRecordDeltaDays,
  workRecordGddDelta
} from './work-record-variance';

export type WorkRecordSaveImpactPanelView = {
  planId: number;
  taskName: string;
  deltaDays: string;
  gddDelta: string;
  unrecordedCount: number;
  averageDeltaDays: string | null;
};

export type WorkRecordSaveImpactRequest = {
  workRecord: WorkRecord;
  mode: WorkRecordSaveMode;
  planId: number;
  gddTrigger?: string | number | null;
};

export function shouldShowWorkRecordSaveImpact(request: WorkRecordSaveImpactRequest): boolean {
  if (request.mode === 'edit') {
    return false;
  }
  if (request.mode === 'create-adhoc' || request.workRecord.task_schedule_item_id == null) {
    return false;
  }
  const deltaDays = workRecordDeltaDays(request.workRecord);
  const gddDelta = workRecordGddDelta(
    request.workRecord,
    parseGddTrigger(request.gddTrigger ?? null)
  );
  return deltaDays != null || gddDelta != null;
}

export function buildWorkRecordSaveImpactPanel(
  request: WorkRecordSaveImpactRequest,
  summary: PlanVsActualSummary
): WorkRecordSaveImpactPanelView | null {
  if (!shouldShowWorkRecordSaveImpact(request)) {
    return null;
  }

  const deltaDays = workRecordDeltaDays(request.workRecord);
  const gddDelta = workRecordGddDelta(
    request.workRecord,
    parseGddTrigger(request.gddTrigger ?? null)
  );
  const stats = buildPlanVsActualPlanSummaryStats(summary);

  return {
    planId: request.planId,
    taskName: request.workRecord.name,
    deltaDays: deltaDays != null ? formatVarianceDeltaDays(deltaDays) : '—',
    gddDelta: gddDelta != null ? formatVarianceGddDelta(gddDelta) : '—',
    unrecordedCount: stats.unrecordedCount,
    averageDeltaDays:
      stats.averageDeltaDays != null
        ? formatPlanTaskScheduleAverageDeltaDaysLabel(stats.averageDeltaDays)
        : null
  };
}

export function workRecordSaveImpactRequestFromSavedEvent(
  event: { workRecord: WorkRecord; mode: WorkRecordSaveMode; gddTrigger?: string | number | null },
  planId: number
): WorkRecordSaveImpactRequest {
  return {
    workRecord: event.workRecord,
    mode: event.mode,
    planId,
    gddTrigger: event.gddTrigger ?? null
  };
}
