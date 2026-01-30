export interface InteractionRule {
  id: number;
  rule_type: string;
  source_group: string;
  target_group: string;
  impact_ratio: number;
  is_directional: boolean;
  description?: string | null;
  is_reference: boolean;
}
