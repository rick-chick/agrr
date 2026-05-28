use serde_json::Value;

/// Ruby: `Domain::InteractionRule::Dtos::InteractionRuleDestroyOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct InteractionRuleDestroyOutput {
    pub undo: Value,
}

impl InteractionRuleDestroyOutput {
    pub fn new(undo: Value) -> Self {
        Self { undo }
    }
}
