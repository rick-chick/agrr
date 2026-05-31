// Tests for `interactors/interaction_rule_update_interactor.rs` (Ruby parity under test/domain/interaction_rule/).

    use crate::interaction_rule::dtos::InteractionRuleUpdateInput;
    use crate::interaction_rule::entities::{InteractionRuleEntity, InteractionRuleEntityAttrs};
    use crate::interaction_rule::gateways::InteractionRuleGateway;
    use crate::interaction_rule::ports::{InteractionRuleUpdateOutputPort, UpdateFailure};
    use crate::shared::attr::{AttrMap, AttrValue};
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
    use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
    use crate::shared::user::User;
    use std::sync::{Arc, Mutex};

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

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

    struct UpdateGateway {
        current: InteractionRuleEntity,
        last_attrs: Arc<Mutex<Option<AttrMap>>>,
        deny_update: bool,
    }

    impl InteractionRuleGateway for UpdateGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.current.clone())
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            attrs: AttrMap,
        ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
            if self.deny_update {
                unimplemented!("must not be called")
            }
            *self.last_attrs.lock().unwrap() = Some(attrs);
            Ok(self.current.clone())
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

    struct SpyUpdate {
        success: bool,
        failure: Option<UpdateFailure>,
    }

    impl InteractionRuleUpdateOutputPort for SpyUpdate {
        fn on_success(&mut self, _: InteractionRuleEntity) {
            self.success = true;
        }

        fn on_failure(&mut self, error: UpdateFailure) {
            self.failure = Some(error);
        }
    }

    fn owned_rule(user_id: i64) -> InteractionRuleEntity {
        InteractionRuleEntity::new(InteractionRuleEntityAttrs {
            id: Some(9),
            user_id: Some(user_id),
            rule_type: "continuous_cultivation".into(),
            source_group: "A".into(),
            target_group: "B".into(),
            impact_ratio: 1.0,
            is_reference: false,
            ..Default::default()
        })
        .unwrap()
    }

    // Ruby: test "calls on_failure with policy exception when interactor denies edit"
    #[test]
    fn calls_on_failure_with_policy_exception_when_interactor_denies_edit() {
        let gateway = UpdateGateway {
            current: owned_rule(99),
            last_attrs: Arc::new(Mutex::new(None)),
            deny_update: true,
        };
        let mut output = SpyUpdate {
            success: false,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = InteractionRuleUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &KeyTranslator,
            &lookup,
        );
        let input = InteractionRuleUpdateInput {
            source_group: Some("変更しようとしたグループ".into()),
            ..InteractionRuleUpdateInput::new(9)
        };
        interactor.call(input).expect("handled");
        assert!(!output.success);
        assert!(matches!(
            output.failure,
            Some(UpdateFailure::Policy(PolicyPermissionDenied))
        ));
    }

    // Ruby: test "一般ユーザーが is_reference フラグを変更しようとすると on_failure（reference_flag_admin_only）"
    #[test]
    fn regular_user_reference_flag_change_fails() {
        let gateway = UpdateGateway {
            current: owned_rule(10),
            last_attrs: Arc::new(Mutex::new(None)),
            deny_update: true,
        };
        let mut output = SpyUpdate {
            success: false,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = InteractionRuleUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &KeyTranslator,
            &lookup,
        );
        let input = InteractionRuleUpdateInput {
            is_reference: Some(true),
            ..InteractionRuleUpdateInput::new(9)
        };
        interactor.call(input).expect("handled");
        match output.failure {
            Some(UpdateFailure::ReferenceFlag(f)) => {
                assert_eq!(f.message, "interaction_rules.flash.reference_flag_admin_only");
                assert_eq!(f.resource_id, 9);
            }
            other => panic!("expected ReferenceFlag failure, got {other:?}"),
        }
    }

    // Ruby: test "admin の region 更新は Policy により保持される"
    #[test]
    fn admin_region_update_is_kept() {
        let last_attrs = Arc::new(Mutex::new(None));
        let gateway = UpdateGateway {
            current: owned_rule(10),
            last_attrs: Arc::clone(&last_attrs),
            deny_update: false,
        };
        let mut output = SpyUpdate {
            success: false,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, true));
        let mut interactor = InteractionRuleUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &KeyTranslator,
            &lookup,
        );
        let input = InteractionRuleUpdateInput {
            region: Some("us".into()),
            ..InteractionRuleUpdateInput::new(9)
        };
        interactor.call(input).expect("handled");
        assert!(output.success);
        let attrs = last_attrs.lock().unwrap().clone().expect("attrs captured");
        assert_eq!(attrs.get("region"), Some(&AttrValue::from("us")));
    }

    // Ruby: test "一般ユーザーの region 更新は Policy により破棄される"
    #[test]
    fn regular_user_region_update_is_stripped() {
        let last_attrs = Arc::new(Mutex::new(None));
        let gateway = UpdateGateway {
            current: owned_rule(10),
            last_attrs: Arc::clone(&last_attrs),
            deny_update: false,
        };
        let mut output = SpyUpdate {
            success: false,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = InteractionRuleUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &KeyTranslator,
            &lookup,
        );
        let input = InteractionRuleUpdateInput {
            region: Some("us".into()),
            ..InteractionRuleUpdateInput::new(9)
        };
        interactor.call(input).expect("handled");
        assert!(output.success);
        let attrs = last_attrs.lock().unwrap().clone().expect("attrs captured");
        assert!(!attrs.contains_key("region"));
    }
