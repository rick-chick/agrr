// Tests for `interactors/interaction_rule_detail_interactor.rs` (Ruby parity under test/domain/interaction_rule/).

    use crate::interaction_rule::dtos::InteractionRuleDetailOutput;
    use crate::interaction_rule::entities::{InteractionRuleEntity, InteractionRuleEntityAttrs};
    use crate::interaction_rule::gateways::InteractionRuleGateway;
    use crate::interaction_rule::ports::{DetailFailure, InteractionRuleDetailOutputPort};
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
    use crate::shared::ports::translator_port::TranslatorPort;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct DetailGateway {
        rule: InteractionRuleEntity,
    }

    impl InteractionRuleGateway for DetailGateway {
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
            unimplemented!()
        }
    }

    struct SpyDetail {
        failure: Option<DetailFailure>,
    }

    impl InteractionRuleDetailOutputPort for SpyDetail {
        fn on_success(&mut self, _: InteractionRuleDetailOutput) {}

        fn on_failure(&mut self, error: DetailFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_rule(user_id: i64) -> InteractionRuleEntity {
        InteractionRuleEntity::new(InteractionRuleEntityAttrs {
            id: Some(3),
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

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_with_policy_exception_when_permission_denied() {
        let gateway = DetailGateway {
            rule: sample_rule(99),
        };
        let mut output = SpyDetail { failure: None };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor =
            InteractionRuleDetailInteractor::new(&mut output, 10, &gateway, &lookup);
        interactor.call(3).expect("handled");
        assert!(matches!(
            output.failure,
            Some(DetailFailure::Policy(PolicyPermissionDenied))
        ));
    }
