import { InteractionRule } from '../../../domain/interaction-rules/interaction-rule';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';

export type InteractionRuleListViewState = {
  loading: boolean;
  error: string | null;
  rules: InteractionRule[];
  pendingUndoToast: PendingUndoToastRequest | null;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface InteractionRuleListView {
  get control(): InteractionRuleListViewState;
  set control(value: InteractionRuleListViewState);
}
