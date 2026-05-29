//! Ruby: `Domain::InteractionRule::Interactors::InteractionRuleCreateInteractor`

use crate::interaction_rule::dtos::InteractionRuleCreateInput;
use crate::interaction_rule::gateways::InteractionRuleGateway;
use crate::interaction_rule::ports::InteractionRuleCreateOutputPort;
use crate::shared::attr::{attr_map_from_pairs, AttrValue};
use crate::shared::dtos::error::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::interaction_rule_policy;
use crate::shared::policies::referencable_resource_policy;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

/// Ruby: `Domain::InteractionRule::Interactors::InteractionRuleCreateInteractor`
pub struct InteractionRuleCreateInteractor<'a, G, O, L, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a L,
}

impl<'a, G, O, L, T> InteractionRuleCreateInteractor<'a, G, O, L, T>
where
    G: InteractionRuleGateway,
    O: InteractionRuleCreateOutputPort,
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
        create_input: InteractionRuleCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let is_reference = create_input.is_reference.unwrap_or(false);
        if is_reference && !user.admin {
            let message = self.translator.t(
                "interaction_rules.flash.reference_only_admin",
                &TranslateOptions::default(),
            );
            self.output_port.on_failure(Error::new(message));
            return Ok(());
        }

        let attrs = interaction_rule_policy::normalize_attrs_for_create(
            &user,
            attr_map_from_pairs([
                ("rule_type", AttrValue::from(create_input.rule_type.as_str())),
                (
                    "source_group",
                    AttrValue::from(create_input.source_group.as_str()),
                ),
                (
                    "target_group",
                    AttrValue::from(create_input.target_group.as_str()),
                ),
                (
                    "impact_ratio",
                    AttrValue::Str(create_input.impact_ratio.to_string()),
                ),
                (
                    "is_directional",
                    create_input
                        .is_directional
                        .map(AttrValue::Bool)
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "description",
                    create_input
                        .description
                        .as_ref()
                        .map(|s| AttrValue::from(s.as_str()))
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "region",
                    create_input
                        .region
                        .as_ref()
                        .map(|s| AttrValue::from(s.as_str()))
                        .unwrap_or(AttrValue::Null),
                ),
                ("is_reference", AttrValue::Bool(is_reference)),
            ]),
        );

        let effective_reference = attrs
            .get("is_reference")
            .map(crate::shared::type_converters::cast_boolean_attr)
            .unwrap_or(false);
        let effective_user_id = match attrs.get("user_id") {
            Some(AttrValue::Int(id)) => Some(*id),
            Some(AttrValue::Null) => None,
            _ => None,
        };

        if !referencable_resource_policy::reference_record_user_id_valid(
            effective_reference,
            effective_user_id,
        ) {
            let message = self.translator.t(
                "activerecord.errors.models.interaction_rule.attributes.user.blank",
                &TranslateOptions::default(),
            );
            return self.handle_record_invalid(message);
        }

        match self.gateway.create_for_user(&user, attrs) {
            Ok(rule_entity) => {
                self.output_port.on_success(rule_entity);
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    let message = record_invalid.to_string();
                    self.output_port.on_failure(Error::new(message));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }

    fn handle_record_invalid(
        &mut self,
        message: String,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.output_port.on_failure(Error::new(message));
        Ok(())
    }
}

#[cfg(test)]
mod interactors_interaction_rule_create_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/interaction_rule/interactors_interaction_rule_create_interactor_test.rs"));
}
