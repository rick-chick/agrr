//! Ruby: `Domain::InteractionRule::Interactors::InteractionRuleDetailInteractor`

use crate::interaction_rule::dtos::InteractionRuleDetailOutput;
use crate::interaction_rule::gateways::InteractionRuleGateway;
use crate::interaction_rule::ports::{DetailFailure, InteractionRuleDetailOutputPort};
use crate::shared::dtos::error::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::interaction_rule_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::reference_record_authorization;

/// Ruby: `Domain::InteractionRule::Interactors::InteractionRuleDetailInteractor`
pub struct InteractionRuleDetailInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a L,
}

impl<'a, G, O, L> InteractionRuleDetailInteractor<'a, G, O, L>
where
    G: InteractionRuleGateway,
    O: InteractionRuleDetailOutputPort,
    L: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        user_lookup: &'a L,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            user_lookup,
        }
    }

    pub fn call(&mut self, rule_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = interaction_rule_policy::record_access_filter(user);
        match self.gateway.find_by_id(rule_id) {
            Ok(rule_entity) => {
                if let Err(policy) =
                    reference_record_authorization::assert_view_allowed(&access_filter, &rule_entity)
                {
                    self.output_port.on_failure(DetailFailure::Policy(policy));
                    return Ok(());
                }
                self.output_port
                    .on_success(InteractionRuleDetailOutput::new(rule_entity));
                Ok(())
            }
            Err(err) => {
                if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
                    self.output_port.on_failure(DetailFailure::Policy(*policy));
                    return Ok(());
                }
                if err.downcast_ref::<RecordInvalidError>().is_some() {
                    self.output_port
                        .on_failure(DetailFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                Err(err)
            }
        }
    }
}
