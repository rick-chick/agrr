import { NavigationExtras, Router } from '@angular/router';

export type PendingNavigationRequest = {
  commands: readonly unknown[];
  extras?: NavigationExtras;
};

interface PendingNavigationViewEffectDeps {
  router: Pick<Router, 'navigate'>;
}

export function consumePendingNavigation<T extends { pendingNavigation: PendingNavigationRequest | null }>(
  state: T,
  deps: PendingNavigationViewEffectDeps
): T {
  const pending = state.pendingNavigation;
  if (!pending) {
    return state;
  }
  void deps.router.navigate(pending.commands as never[], pending.extras);
  return { ...state, pendingNavigation: null };
}

/** Component control setter で pending navigation を消費する。 */
export const applyPendingNavigationViewEffects = consumePendingNavigation;
