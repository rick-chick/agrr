import type { WorkRecordSheetSavedEvent } from '../../components/plans/work-record-sheet.view';
import { buildPlanVsActualPlanSummaryStats } from '../../domain/plans/build-plan-vs-actual-plan-summary';
import { buildWorkRecordSaveImpact } from '../../domain/plans/work-record-save-impact';
import type { WorkRecordSaveImpactViewModel } from '../../domain/plans/work-record-save-impact';
import type { WorkRecordSaveToastContext } from '../../domain/plans/work-record-save-toast';
import type { PlanVsActualSummaryDataDto } from '../../usecase/plans/load-plan-vs-actual-summary.output-port';

export type PendingSaveImpactRequest = {
  event: WorkRecordSheetSavedEvent;
  context: WorkRecordSaveToastContext | null;
};

export type PlanSaveImpactViewFields = {
  saveImpact: WorkRecordSaveImpactViewModel | null;
  saveImpactLoading: boolean;
  saveImpactError: string | null;
};

export const emptyPlanSaveImpactViewFields: PlanSaveImpactViewFields = {
  saveImpact: null,
  saveImpactLoading: false,
  saveImpactError: null
};

export function beginPlanSaveImpactLoad(
  pending: PendingSaveImpactRequest | null,
  loadGeneration: number
): { pending: PendingSaveImpactRequest | null; loadGeneration: number; fields: PlanSaveImpactViewFields } {
  return {
    pending,
    loadGeneration,
    fields: {
      saveImpact: null,
      saveImpactLoading: true,
      saveImpactError: null
    }
  };
}

export function applyPlanSaveImpactSummary(
  pending: PendingSaveImpactRequest | null,
  loadGeneration: number,
  activeLoadGeneration: number,
  dto: PlanVsActualSummaryDataDto
): { pending: PendingSaveImpactRequest | null; fields: PlanSaveImpactViewFields } | null {
  if (pending == null || dto.loadGeneration !== activeLoadGeneration) {
    return null;
  }

  const planStats = buildPlanVsActualPlanSummaryStats(dto.summary);
  const saveImpact = buildWorkRecordSaveImpact(
    pending.event.workRecord,
    pending.event.mode,
    planStats,
    pending.context
  );

  return {
    pending: null,
    fields: {
      saveImpact,
      saveImpactLoading: false,
      saveImpactError: null
    }
  };
}

export function planSaveImpactErrorFields(message: string): PlanSaveImpactViewFields {
  return {
    saveImpact: null,
    saveImpactLoading: false,
    saveImpactError: message
  };
}
