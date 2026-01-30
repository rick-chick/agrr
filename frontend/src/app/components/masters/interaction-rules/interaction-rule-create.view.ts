export type InteractionRuleCreateFormData = {
  rule_type: string;
  source_group: string;
  target_group: string;
  impact_ratio: number;
  is_directional: boolean;
  description: string | null;
  region: string | null;
};

export type InteractionRuleCreateViewState = {
  saving: boolean;
  error: string | null;
  formData: InteractionRuleCreateFormData;
};

export interface InteractionRuleCreateView {
  get control(): InteractionRuleCreateViewState;
  set control(value: InteractionRuleCreateViewState);
}