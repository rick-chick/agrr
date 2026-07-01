import {
  consumePendingToastKey,
  PendingToastViewEffectDeps
} from '../../core/view-effects/pending-toast-view.effects';

interface ContactFormViewEffectState {
  pendingToastKey: string | null;
}

export function applyContactFormViewEffects<T extends ContactFormViewEffectState>(
  next: T,
  deps: PendingToastViewEffectDeps
): T {
  return consumePendingToastKey(
    next,
    next.pendingToastKey,
    (state) => ({ ...state, pendingToastKey: null }),
    deps
  );
}
