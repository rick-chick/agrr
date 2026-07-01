import { InteractionRule } from '../../../domain/interaction-rules/interaction-rule';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';

export type InteractionRuleDetailViewState = {
  loading: boolean;
  error: string | null;
  rule: InteractionRule | null;
  pendingUndoToast: PendingUndoToastRequest | null;
};

export interface InteractionRuleDetailView {
  get control(): InteractionRuleDetailViewState;
  set control(value: InteractionRuleDetailViewState);
  /** Reload detail (e.g. after undo restore). */
  reload(): void;
}