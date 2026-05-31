//! Ruby: `Domain::InteractionRule::Interactors::InteractionRuleDestroyInteractor`

use crate::interaction_rule::dtos::InteractionRuleDestroyOutput;
use crate::interaction_rule::gateways::{InteractionRuleGateway, SoftDeleteWithUndoOutcome};
use crate::interaction_rule::ports::{DestroyFailure, InteractionRuleDestroyOutputPort};
use crate::shared::dtos::error::Error;
use crate::shared::exceptions::{AssociationInUseError, RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::interaction_rule_policy;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

/// Ruby: `Domain::InteractionRule::Interactors::InteractionRuleDestroyInteractor`
pub struct InteractionRuleDestroyInteractor<'a, G, O, L, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a L,
}

impl<'a, G, O, L, T> InteractionRuleDestroyInteractor<'a, G, O, L, T>
where
    G: InteractionRuleGateway,
    O: InteractionRuleDestroyOutputPort,
    L: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        translator: &'a T,
        user_lookup: &'a L,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            translator,
            user_lookup,
        }
    }

    pub fn call(&mut self, rule_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = interaction_rule_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(rule_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("interaction_rules.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &current)
        {
            self.output_port.on_failure(DestroyFailure::Policy(policy));
            return Ok(());
        }

        match self
            .gateway
            .soft_delete_with_undo(&user, rule_id, 5000, self.translator)
        {
            Ok(SoftDeleteWithUndoOutcome::Success(success)) => {
                self.output_port.on_success(InteractionRuleDestroyOutput::new(success.undo));
                Ok(())
            }
            Ok(SoftDeleteWithUndoOutcome::Failure(error_dto)) => {
                self.output_port.on_failure(DestroyFailure::Error(error_dto));
                Ok(())
            }
            Err(err) => {
                if err
                    .downcast_ref::<crate::shared::policies::policy_permission_denied::PolicyPermissionDenied>()
                    .is_some()
                {
                    self.output_port.on_failure(DestroyFailure::Policy(
                        crate::shared::policies::policy_permission_denied::PolicyPermissionDenied,
                    ));
                    return Ok(());
                }
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("interaction_rules.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                if err.downcast_ref::<RecordInvalidError>().is_some() {
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                if err.downcast_ref::<AssociationInUseError>().is_some() {
                    let message = self
                        .translator
                        .t("interaction_rules.flash.cannot_delete_in_use", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                Err(err)
            }
        }
    }
}

#[cfg(test)]
mod interactors_interaction_rule_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/interaction_rule/interactors_interaction_rule_destroy_interactor_test.rs"));
}
