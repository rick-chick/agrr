//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveInteractionRuleReferenceRow`

/// Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveInteractionRuleReferenceRow`
#[derive(Debug, Clone)]
pub struct PublicPlanSaveInteractionRuleReferenceRow {
    pub reference_interaction_rule_id: i64,
    pub rule_type: String,
    pub source_group: String,
    pub target_group: String,
    pub impact_ratio: f64,
    pub is_directional: bool,
    pub region: Option<String>,
    pub description: Option<String>,
}

impl PublicPlanSaveInteractionRuleReferenceRow {
    pub fn new(
        reference_interaction_rule_id: i64,
        rule_type: impl Into<String>,
        source_group: impl Into<String>,
        target_group: impl Into<String>,
        impact_ratio: f64,
        is_directional: bool,
        region: Option<String>,
        description: Option<String>,
    ) -> Self {
        Self {
            reference_interaction_rule_id,
            rule_type: rule_type.into(),
            source_group: source_group.into(),
            target_group: target_group.into(),
            impact_ratio,
            is_directional,
            region,
            description,
        }
    }
}
