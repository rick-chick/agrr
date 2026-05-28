//! Plan-save interaction rule DTOs.

#[derive(Debug, Clone)]
pub struct PlanSaveUserInteractionRuleSnapshot {
    pub id: i64,
    pub source_interaction_rule_id: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct PlanSaveEnsureUserInteractionRulesInput {
    pub user_id: i64,
    pub region: Option<String>,
    pub reference_crop_groups: Vec<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PlanSaveEnsureUserInteractionRulesOutput {
    pub user_interaction_rule_ids: Vec<i64>,
    pub skipped_interaction_rule_ids: Vec<i64>,
}
