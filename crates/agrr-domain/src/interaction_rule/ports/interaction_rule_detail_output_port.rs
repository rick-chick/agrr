use crate::interaction_rule::dtos::InteractionRuleDetailOutput;
use crate::shared::dtos::error::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::InteractionRule::Ports::InteractionRuleDetailOutputPort`
pub trait InteractionRuleDetailOutputPort {
    fn on_success(&mut self, dto: InteractionRuleDetailOutput);
    fn on_failure(&mut self, error: DetailFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum DetailFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
