use crate::interaction_rule::entities::InteractionRuleEntity;
use crate::shared::dtos::error::Error;
use crate::shared::dtos::reference_flag_change_denied_failure::ReferenceFlagChangeDeniedFailure;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::InteractionRule::Ports::InteractionRuleUpdateOutputPort`
pub trait InteractionRuleUpdateOutputPort {
    fn on_success(&mut self, rule: InteractionRuleEntity);
    fn on_failure(&mut self, error: UpdateFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum UpdateFailure {
    Policy(PolicyPermissionDenied),
    ReferenceFlag(ReferenceFlagChangeDeniedFailure),
    Error(Error),
}
