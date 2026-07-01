import { consumePendingToastKey } from '../../core/view-effects/pending-toast-view.effects';
import {
  applyTaskScheduleSyncViewEffects,
  TaskScheduleSyncViewEffectDeps,
} from './task-schedule-sync-view.effects';

interface PlanWorkViewEffectState {
  pendingSyncToastKey: string | null;
  pendingRecordSavedToastKey: string | null;
  syncReloadNonce: number;
}

export function applyPlanWorkViewEffects<T extends PlanWorkViewEffectState>(
  prev: T,
  next: T,
  deps: TaskScheduleSyncViewEffectDeps
): T {
  const state = applyTaskScheduleSyncViewEffects(prev, next, deps);
  return consumePendingToastKey(
    state,
    state.pendingRecordSavedToastKey,
    (current) => ({ ...current, pendingRecordSavedToastKey: null }),
    deps
  );
}
