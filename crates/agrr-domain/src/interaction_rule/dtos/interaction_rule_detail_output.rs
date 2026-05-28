use crate::interaction_rule::entities::InteractionRuleEntity;

/// Ruby: `Domain::InteractionRule::Dtos::InteractionRuleDetailOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct InteractionRuleDetailOutput {
    pub rule: InteractionRuleEntity,
}

impl InteractionRuleDetailOutput {
    pub fn new(rule: InteractionRuleEntity) -> Self {
        Self { rule }
    }
}
