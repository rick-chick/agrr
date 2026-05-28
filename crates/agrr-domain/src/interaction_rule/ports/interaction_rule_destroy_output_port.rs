use crate::interaction_rule::dtos::InteractionRuleDestroyOutput;
use crate::shared::dtos::error::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::InteractionRule::Ports::InteractionRuleDestroyOutputPort`
pub trait InteractionRuleDestroyOutputPort {
    fn on_success(&mut self, dto: InteractionRuleDestroyOutput);
    fn on_failure(&mut self, error: DestroyFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum DestroyFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
