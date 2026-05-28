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
mod tests {
    use super::*;
    use crate::interaction_rule::entities::{InteractionRuleEntity, InteractionRuleEntityAttrs};
    use crate::shared::attr::{AttrMap, AttrValue};
    use crate::shared::user::User;
    use std::sync::{Arc, Mutex};

    struct KeyTranslator;
    impl TranslatorPort for KeyTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(
            &self,
            _: time::Date,
            _: Option<&str>,
            _: &TranslateOptions,
        ) -> String {
            String::new()
        }
    }

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct SpyCreate {
        success: Option<InteractionRuleEntity>,
        failure: Option<Error>,
    }
    impl InteractionRuleCreateOutputPort for SpyCreate {
        fn on_success(&mut self, rule: InteractionRuleEntity) {
            self.success = Some(rule);
        }
        fn on_failure(&mut self, error: Error) {
            self.failure = Some(error);
        }
    }

    struct SpyGateway {
        last_attrs: Arc<Mutex<Option<AttrMap>>>,
        return_entity: InteractionRuleEntity,
    }
    impl InteractionRuleGateway for SpyGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<InteractionRuleEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            attrs: AttrMap,
        ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
            *self.last_attrs.lock().unwrap() = Some(attrs);
            Ok(self.return_entity.clone())
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::interaction_rule::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
    }

    fn sample_entity() -> InteractionRuleEntity {
        InteractionRuleEntity::new(InteractionRuleEntityAttrs {
            rule_type: "continuous_cultivation".into(),
            source_group: "A".into(),
            target_group: "B".into(),
            impact_ratio: 1.0,
            is_reference: false,
            ..Default::default()
        })
        .unwrap()
    }

    fn build_input(is_reference: Option<bool>, region: Option<&str>) -> InteractionRuleCreateInput {
        InteractionRuleCreateInput::new(
            "continuous_cultivation",
            "A",
            "B",
            1.0,
            None,
            None,
            region.map(str::to_string),
            is_reference,
        )
    }

    // Ruby: test "一般ユーザーが参照ルールを作成しようとすると on_failure（reference_only_admin）"
    #[test]
    fn regular_user_reference_create_fails() {
        let gateway = SpyGateway {
            last_attrs: Arc::new(Mutex::new(None)),
            return_entity: sample_entity(),
        };
        let translator = KeyTranslator;
        let mut output = SpyCreate {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(7, false));
        let mut interactor =
            InteractionRuleCreateInteractor::new(&mut output, 7, &gateway, &translator, &lookup);
        interactor.call(build_input(Some(true), None)).unwrap();
        assert_eq!(
            output.failure.unwrap().message,
            "interaction_rules.flash.reference_only_admin"
        );
    }

    // Ruby: test "admin は参照ルールを作成でき on_success"
    #[test]
    fn admin_reference_create_succeeds() {
        let gateway = SpyGateway {
            last_attrs: Arc::new(Mutex::new(None)),
            return_entity: sample_entity(),
        };
        let translator = KeyTranslator;
        let mut output = SpyCreate {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(7, true));
        let mut interactor =
            InteractionRuleCreateInteractor::new(&mut output, 7, &gateway, &translator, &lookup);
        interactor.call(build_input(Some(true), None)).unwrap();
        assert!(output.success.is_some());
        let attrs = gateway.last_attrs.lock().unwrap().clone().unwrap();
        assert_eq!(attrs.get("is_reference"), Some(&AttrValue::Bool(true)));
        assert_eq!(attrs.get("user_id"), Some(&AttrValue::Null));
    }

    // Ruby: test "一般ユーザーの region 指定は Policy により破棄される"
    #[test]
    fn regular_user_region_stripped() {
        let gateway = SpyGateway {
            last_attrs: Arc::new(Mutex::new(None)),
            return_entity: sample_entity(),
        };
        let translator = KeyTranslator;
        let mut output = SpyCreate {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(7, false));
        let mut interactor =
            InteractionRuleCreateInteractor::new(&mut output, 7, &gateway, &translator, &lookup);
        interactor
            .call(build_input(Some(false), Some("us")))
            .unwrap();
        let attrs = gateway.last_attrs.lock().unwrap().clone().unwrap();
        assert!(!attrs.contains_key("region"));
    }
}
