//! Ruby: `Domain::InteractionRule::Interactors::InteractionRuleListInteractor`

use crate::interaction_rule::gateways::InteractionRuleGateway;
use crate::interaction_rule::ports::{InteractionRuleListOutputPort, ListFailure};
use crate::shared::dtos::error::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::interaction_rule_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::InteractionRule::Interactors::InteractionRuleListInteractor`
pub struct InteractionRuleListInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a L,
}

impl<'a, G, O, L> InteractionRuleListInteractor<'a, G, O, L>
where
    G: InteractionRuleGateway,
    O: InteractionRuleListOutputPort,
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

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let filter = interaction_rule_policy::index_list_filter(&user);
        match self.gateway.list_index_for_filter(&filter) {
            Ok(rules) => {
                self.output_port.on_success(rules);
                Ok(())
            }
            Err(err) => {
                if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
                    self.output_port.on_failure(ListFailure::Policy(*policy));
                    return Ok(());
                }
                if err.downcast_ref::<RecordInvalidError>().is_some() {
                    self.output_port
                        .on_failure(ListFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                Err(err)
            }
        }
    }
}
