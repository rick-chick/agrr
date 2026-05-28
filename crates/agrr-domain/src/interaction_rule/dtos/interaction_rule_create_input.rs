/// Ruby: `Domain::InteractionRule::Dtos::InteractionRuleCreateInput`
#[derive(Debug, Clone, PartialEq)]
pub struct InteractionRuleCreateInput {
    pub rule_type: String,
    pub source_group: String,
    pub target_group: String,
    pub impact_ratio: f64,
    pub is_directional: Option<bool>,
    pub description: Option<String>,
    pub region: Option<String>,
    pub is_reference: Option<bool>,
}

impl InteractionRuleCreateInput {
    pub fn new(
        rule_type: impl Into<String>,
        source_group: impl Into<String>,
        target_group: impl Into<String>,
        impact_ratio: f64,
        is_directional: Option<bool>,
        description: Option<String>,
        region: Option<String>,
        is_reference: Option<bool>,
    ) -> Self {
        Self {
            rule_type: rule_type.into(),
            source_group: source_group.into(),
            target_group: target_group.into(),
            impact_ratio,
            is_directional,
            description,
            region,
            is_reference,
        }
    }
}
