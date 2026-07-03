import { FlashMessageService } from '../../services/flash-message.service';

export interface PendingToastViewEffectDeps {
  flash: Pick<FlashMessageService, 'show'>;
}

export function consumePendingToastKey<T>(
  state: T,
  pendingToastKey: string | null | undefined,
  clearPendingToastKey: (state: T) => T,
  deps: PendingToastViewEffectDeps
): T {
  if (!pendingToastKey) {
    return state;
  }
  deps.flash.show({ type: 'success', text: pendingToastKey });
  return clearPendingToastKey(state);
}
