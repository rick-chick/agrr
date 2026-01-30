import { InteractionRule } from '../../../domain/interaction-rules/interaction-rule';

export type InteractionRuleListViewState = {
  loading: boolean;
  error: string | null;
  rules: InteractionRule[];
};

export interface InteractionRuleListView {
  get control(): InteractionRuleListViewState;
  set control(value: InteractionRuleListViewState);
}
