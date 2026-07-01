import { FlashMessageService } from '../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from './pending-error-flash-view.effects';
import { PendingErrorFlashRequest } from './pending-error-flash-view.effects';

export type PendingSuccessFlashRequest = {
  type: 'success';
  text: string;
};

interface PendingSuccessFlashViewEffectDeps {
  flash: Pick<FlashMessageService, 'show'>;
}

export function consumePendingSuccessFlash<T extends { pendingSuccessFlash: PendingSuccessFlashRequest | null }>(
  state: T,
  deps: PendingSuccessFlashViewEffectDeps
): T {
  const pending = state.pendingSuccessFlash;
  if (!pending) {
    return state;
  }
  deps.flash.show(pending);
  return { ...state, pendingSuccessFlash: null };
}

/** Component control setter で pending success flash を消費する。 */
export const applyPendingSuccessFlashViewEffects = consumePendingSuccessFlash;

type PendingFlashViewEffectState = {
  pendingErrorFlash: PendingErrorFlashRequest | null;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
};

/** error / success の pending flash を順に消費する。 */
export function applyPendingFlashViewEffects<T extends PendingFlashViewEffectState>(
  state: T,
  deps: PendingSuccessFlashViewEffectDeps
): T {
  return applyPendingSuccessFlashViewEffects(applyPendingErrorFlashViewEffects(state, deps), deps);
}
