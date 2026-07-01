import { InteractionRule } from '../../../domain/interaction-rules/interaction-rule';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';

export type InteractionRuleListViewState = {
  loading: boolean;
  error: string | null;
  rules: InteractionRule[];
  pendingUndoToast: PendingUndoToastRequest | null;
};

export interface InteractionRuleListView {
  get control(): InteractionRuleListViewState;
  set control(value: InteractionRuleListViewState);
}
