import { InteractionRule } from '../../../domain/interaction-rules/interaction-rule';

export type InteractionRuleDetailViewState = {
  loading: boolean;
  error: string | null;
  rule: InteractionRule | null;
};

export interface InteractionRuleDetailView {
  get control(): InteractionRuleDetailViewState;
  set control(value: InteractionRuleDetailViewState);
}