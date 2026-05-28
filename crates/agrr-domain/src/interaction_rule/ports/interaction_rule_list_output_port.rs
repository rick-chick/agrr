use crate::interaction_rule::entities::InteractionRuleEntity;
use crate::shared::dtos::error::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::InteractionRule::Ports::InteractionRuleListOutputPort`
pub trait InteractionRuleListOutputPort {
    fn on_success(&mut self, rules: Vec<InteractionRuleEntity>);
    fn on_failure(&mut self, error: ListFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum ListFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
