import { TranslateService } from '@ngx-translate/core';
import { UndoToastService } from '../../services/undo-toast.service';

export interface PendingToastViewEffectDeps {
  toast: Pick<UndoToastService, 'show'>;
  translate: Pick<TranslateService, 'instant'>;
}

export type TaskScheduleSyncViewEffectDeps = PendingToastViewEffectDeps & {
  onReload: () => void;
};

export function consumePendingToastKey<T>(
  state: T,
  pendingToastKey: string | null | undefined,
  clearPendingToastKey: (state: T) => T,
  deps: PendingToastViewEffectDeps
): T {
  if (!pendingToastKey) {
    return state;
  }
  deps.toast.show(deps.translate.instant(pendingToastKey));
  return clearPendingToastKey(state);
}
