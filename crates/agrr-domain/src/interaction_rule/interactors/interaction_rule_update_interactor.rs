//! Ruby: `Domain::InteractionRule::Interactors::InteractionRuleUpdateInteractor`

use crate::interaction_rule::dtos::InteractionRuleUpdateInput;
use crate::interaction_rule::gateways::InteractionRuleGateway;
use crate::interaction_rule::ports::{InteractionRuleUpdateOutputPort, UpdateFailure};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::dtos::error::Error;
use crate::shared::dtos::reference_flag_change_denied_failure::ReferenceFlagChangeDeniedFailure;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::interaction_rule_policy;
use crate::shared::policies::referencable_resource_policy;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;
use crate::shared::type_converters::cast_boolean_attr;

/// Ruby: `Domain::InteractionRule::Interactors::InteractionRuleUpdateInteractor`
pub struct InteractionRuleUpdateInteractor<'a, G, O, L, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a L,
}

impl<'a, G, O, L, T> InteractionRuleUpdateInteractor<'a, G, O, L, T>
where
    G: InteractionRuleGateway,
    O: InteractionRuleUpdateOutputPort,
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

    pub fn call(
        &mut self,
        update_input: InteractionRuleUpdateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = interaction_rule_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(update_input.id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    self.output_port
                        .on_failure(UpdateFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &current)
        {
            self.output_port.on_failure(UpdateFailure::Policy(policy));
            return Ok(());
        }

        if let Some(requested_ref) = update_input.is_reference {
            let requested = requested_ref;
            if !referencable_resource_policy::reference_flag_change_allowed(
                &user,
                requested,
                current.reference(),
            ) {
                let message = self.translator.t(
                    "interaction_rules.flash.reference_flag_admin_only",
                    &opts,
                );
                self.output_port.on_failure(UpdateFailure::ReferenceFlag(
                    ReferenceFlagChangeDeniedFailure::new(message, update_input.id),
                ));
                return Ok(());
            }
        }

        let mut attrs = AttrMap::new();
        if let Some(v) = update_input.rule_type {
            attrs.insert("rule_type".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.source_group {
            attrs.insert("source_group".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.target_group {
            attrs.insert("target_group".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.impact_ratio {
            attrs.insert("impact_ratio".into(), AttrValue::Str(v.to_string()));
        }
        if let Some(v) = update_input.is_directional {
            attrs.insert("is_directional".into(), AttrValue::Bool(v));
        }
        if let Some(v) = update_input.description {
            attrs.insert("description".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.region {
            attrs.insert("region".into(), AttrValue::from(v.as_str()));
        }
        if let Some(v) = update_input.is_reference {
            attrs.insert("is_reference".into(), AttrValue::Bool(v));
        }

        let normalized = interaction_rule_policy::normalize_attrs_for_update(
            &user,
            attr_map_from_pairs([("is_reference", AttrValue::Bool(current.reference()))]),
            attrs,
        );

        let effective_reference = normalized
            .get("is_reference")
            .map(cast_boolean_attr)
            .unwrap_or(current.reference());
        let effective_user_id = match normalized.get("user_id") {
            Some(AttrValue::Int(id)) => Some(*id),
            Some(AttrValue::Null) => None,
            _ => current.user_id,
        };

        if !referencable_resource_policy::reference_record_user_id_valid(
            effective_reference,
            effective_user_id,
        ) {
            let message = self.translator.t(
                "activerecord.errors.models.interaction_rule.attributes.user.blank",
                &opts,
            );
            self.output_port
                .on_failure(UpdateFailure::Error(Error::new(message)));
            return Ok(());
        }

        match self.gateway.update_for_user(&user, update_input.id, normalized) {
            Ok(rule_entity) => {
                self.output_port.on_success(rule_entity);
                Ok(())
            }
            Err(err) => {
                if err
                    .downcast_ref::<crate::shared::policies::policy_permission_denied::PolicyPermissionDenied>()
                    .is_some()
                {
                    self.output_port.on_failure(UpdateFailure::Policy(
                        crate::shared::policies::policy_permission_denied::PolicyPermissionDenied,
                    ));
                    return Ok(());
                }
                if err.downcast_ref::<RecordNotFoundError>().is_some()
                    || err.downcast_ref::<RecordInvalidError>().is_some()
                {
                    self.output_port
                        .on_failure(UpdateFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                Err(err)
            }
        }
    }
}
