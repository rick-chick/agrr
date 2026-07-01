import {
  consumePendingToastKey,
  PendingToastViewEffectDeps,
} from '../../core/view-effects/pending-toast-view.effects';

export type TaskScheduleSyncViewEffectDeps = PendingToastViewEffectDeps & {
  onReload: () => void;
};

interface TaskScheduleSyncViewEffectState {
  pendingSyncToastKey: string | null;
  syncReloadNonce: number;
}

export function applyTaskScheduleSyncViewEffects<T extends TaskScheduleSyncViewEffectState>(
  prev: T,
  next: T,
  deps: TaskScheduleSyncViewEffectDeps
): T {
  if (next.syncReloadNonce !== prev.syncReloadNonce && next.syncReloadNonce > 0) {
    deps.onReload();
  }
  return consumePendingToastKey(
    next,
    next.pendingSyncToastKey,
    (state) => ({ ...state, pendingSyncToastKey: null }),
    deps
  );
}
