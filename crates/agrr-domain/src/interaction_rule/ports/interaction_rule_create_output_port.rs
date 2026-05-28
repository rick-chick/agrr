use crate::interaction_rule::entities::InteractionRuleEntity;
use crate::shared::dtos::error::Error;

/// Ruby: `Domain::InteractionRule::Ports::InteractionRuleCreateOutputPort`
pub trait InteractionRuleCreateOutputPort {
    fn on_success(&mut self, rule: InteractionRuleEntity);
    fn on_failure(&mut self, error: Error);
}
