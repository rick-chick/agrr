import { CanDeactivateFn } from '@angular/router';

export interface UnsavedChangesDeactivatable {
  hasUnsavedChanges(): boolean;
  confirmDiscardUnsavedChanges(): boolean | Promise<boolean>;
}

export const unsavedChangesGuard: CanDeactivateFn<UnsavedChangesDeactivatable> = (component) => {
  if (!component?.hasUnsavedChanges?.()) {
    return true;
  }
  return component.confirmDiscardUnsavedChanges();
};
