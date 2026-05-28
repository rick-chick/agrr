/// Ruby: `Domain::InteractionRule::Dtos::InteractionRuleUpdateInput`
#[derive(Debug, Clone, PartialEq)]
pub struct InteractionRuleUpdateInput {
    pub id: i64,
    pub rule_type: Option<String>,
    pub source_group: Option<String>,
    pub target_group: Option<String>,
    pub impact_ratio: Option<f64>,
    pub is_directional: Option<bool>,
    pub description: Option<String>,
    pub region: Option<String>,
    pub is_reference: Option<bool>,
}

impl InteractionRuleUpdateInput {
    pub fn new(id: i64) -> Self {
        Self {
            id,
            rule_type: None,
            source_group: None,
            target_group: None,
            impact_ratio: None,
            is_directional: None,
            description: None,
            region: None,
            is_reference: None,
        }
    }
}
