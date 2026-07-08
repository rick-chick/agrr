import { FlashMessageService } from '../../services/flash-message.service';

export type PendingErrorFlashRequest = {
  type: 'error';
  text: string;
};

interface PendingErrorFlashViewEffectDeps {
  flash: Pick<FlashMessageService, 'show'>;
}

export function consumePendingErrorFlash<T extends { pendingErrorFlash: PendingErrorFlashRequest | null }>(
  state: T,
  deps: PendingErrorFlashViewEffectDeps
): T {
  const pending = state.pendingErrorFlash;
  if (!pending) {
    return state;
  }
  deps.flash.show(pending);
  return { ...state, pendingErrorFlash: null };
}

/** Component control setter で pending error flash を消費する。 */
export const applyPendingErrorFlashViewEffects = consumePendingErrorFlash;
