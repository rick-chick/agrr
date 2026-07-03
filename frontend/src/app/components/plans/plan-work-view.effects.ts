import { consumePendingToastKey } from '../../core/view-effects/pending-toast-view.effects';
import { WorkRecordSheetSavedEvent } from './work-record-sheet.view';
import { planWorkRecordSavedPatch } from './plan-work-record-saved-view';
import {
  applyTaskScheduleSyncViewEffects,
  TaskScheduleSyncViewEffectDeps,
} from './task-schedule-sync-view.effects';

interface PlanWorkViewEffectState {
  pendingSyncToastKey: string | null;
  pendingRecordSavedToastKey: string | null;
  pendingRecordSavedEvent: WorkRecordSheetSavedEvent | null;
  pendingQuickCompleteValidation: {
    itemId: number;
    fieldErrors: Record<string, string[]>;
  } | null;
  syncReloadNonce: number;
  recentAdHocRecord: { name: string; actualDate: string } | null;
  highlightedItemId: number | null;
}

export type PlanWorkViewEffectDeps = TaskScheduleSyncViewEffectDeps & {
  scheduleHighlightClear: (itemId: number) => void;
  onQuickCompleteValidation: (itemId: number, fieldErrors: Record<string, string[]>) => void;
};

export function applyPlanWorkViewEffects<T extends PlanWorkViewEffectState>(
  prev: T,
  next: T,
  deps: PlanWorkViewEffectDeps
): T {
  let state = applyTaskScheduleSyncViewEffects(prev, next, deps);
  state = consumePendingToastKey(
    state,
    state.pendingRecordSavedToastKey,
    (current) => ({ ...current, pendingRecordSavedToastKey: null }),
    deps
  );

  if (
    next.pendingRecordSavedEvent !== prev.pendingRecordSavedEvent &&
    next.pendingRecordSavedEvent != null
  ) {
    const patch = planWorkRecordSavedPatch(next.pendingRecordSavedEvent);
    state = { ...state, ...patch, pendingRecordSavedEvent: null };
    if (patch.highlightedItemId != null) {
      deps.scheduleHighlightClear(patch.highlightedItemId);
    }
    deps.onReload();
  }

  if (
    next.pendingQuickCompleteValidation !== prev.pendingQuickCompleteValidation &&
    next.pendingQuickCompleteValidation != null
  ) {
    const { itemId, fieldErrors } = next.pendingQuickCompleteValidation;
    deps.onQuickCompleteValidation(itemId, fieldErrors);
    state = { ...state, pendingQuickCompleteValidation: null };
  }

  return state;
}
