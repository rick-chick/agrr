import { NavigationExtras } from '@angular/router';
import { PendingNavigationRequest } from './pending-navigation-view.effects';

export function pendingNavigationTo(
  commands: readonly unknown[],
  extras?: NavigationExtras
): PendingNavigationRequest {
  return { commands, extras };
}
