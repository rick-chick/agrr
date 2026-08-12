import { FlashMessageService } from '../../services/flash-message.service';

export type FlashMessageAction = {
  labelKey: string;
  routerLink: (string | number)[];
  queryParams?: Record<string, string | number>;
};

export type PendingToastRequest = {
  textKey: string;
  textParams?: Record<string, string | number>;
  action?: FlashMessageAction;
};

export interface PendingToastViewEffectDeps {
  flash: Pick<FlashMessageService, 'show'>;
}

export function consumePendingToastKey<T>(
  state: T,
  pendingToast: string | PendingToastRequest | null | undefined,
  clearPendingToastKey: (state: T) => T,
  deps: PendingToastViewEffectDeps
): T {
  if (!pendingToast) {
    return state;
  }
  if (typeof pendingToast === 'string') {
    deps.flash.show({ type: 'success', text: pendingToast });
  } else {
    deps.flash.show({
      type: 'success',
      text: pendingToast.textKey,
      textParams: pendingToast.textParams,
      action: pendingToast.action
    });
  }
  return clearPendingToastKey(state);
}
