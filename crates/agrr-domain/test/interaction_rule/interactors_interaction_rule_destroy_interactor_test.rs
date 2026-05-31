// Tests for `interactors/interaction_rule_destroy_interactor.rs` (Ruby parity under test/domain/interaction_rule/).

    use crate::interaction_rule::dtos::InteractionRuleDestroyOutput;
    use crate::interaction_rule::entities::{InteractionRuleEntity, InteractionRuleEntityAttrs};
    use crate::interaction_rule::gateways::InteractionRuleGateway;
    use crate::interaction_rule::ports::{DestroyFailure, InteractionRuleDestroyOutputPort};
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
    use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
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

    struct DestroyGateway {
        rule: InteractionRuleEntity,
    }

    impl InteractionRuleGateway for DestroyGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.rule.clone())
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
            _: crate::shared::attr::AttrMap,
        ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
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
            unimplemented!("must not be called")
        }
    }

    struct SpyDestroy {
        failure: Option<DestroyFailure>,
    }

    impl InteractionRuleDestroyOutputPort for SpyDestroy {
        fn on_success(&mut self, _: InteractionRuleDestroyOutput) {}

        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_rule(user_id: i64) -> InteractionRuleEntity {
        InteractionRuleEntity::new(InteractionRuleEntityAttrs {
            id: Some(7),
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

    // Ruby: test "calls on_failure with policy exception when interactor denies destroy"
    #[test]
    fn calls_on_failure_with_policy_exception_when_interactor_denies_destroy() {
        let gateway = DestroyGateway {
            rule: sample_rule(99),
        };
        let mut output = SpyDestroy { failure: None };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = InteractionRuleDestroyInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        interactor.call(7).expect("handled");
        assert!(matches!(
            output.failure,
            Some(DestroyFailure::Policy(PolicyPermissionDenied))
        ));
    }
