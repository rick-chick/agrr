export type InteractionRuleEditFormData = {
  rule_type: string;
  source_group: string;
  target_group: string;
  impact_ratio: number;
  is_directional: boolean;
  description: string | null;
  region: string | null;
};

export type InteractionRuleEditViewState = {
  loading: boolean;
  saving: boolean;
  error: string | null;
  formData: InteractionRuleEditFormData;
};

export interface InteractionRuleEditView {
  get control(): InteractionRuleEditViewState;
  set control(value: InteractionRuleEditViewState);
}