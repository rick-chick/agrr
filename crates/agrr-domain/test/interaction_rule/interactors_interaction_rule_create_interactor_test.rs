// Tests for `interactors/interaction_rule_create_interactor.rs` (Ruby parity under test/domain/interaction_rule/).

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
