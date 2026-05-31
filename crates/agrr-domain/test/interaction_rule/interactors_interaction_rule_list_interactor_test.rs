// Tests for `interactors/interaction_rule_list_interactor.rs` (Ruby parity under test/domain/interaction_rule/).

    use crate::interaction_rule::entities::{InteractionRuleEntity, InteractionRuleEntityAttrs};
    use crate::interaction_rule::gateways::InteractionRuleGateway;
    use crate::interaction_rule::ports::{InteractionRuleListOutputPort, ListFailure};
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
    use crate::shared::ports::translator_port::TranslatorPort;
    use crate::shared::user::User;
    use crate::shared::value_objects::reference_index_list_filter::{
        ReferenceIndexListFilter, ReferenceIndexListMode,
    };

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct ListGateway {
        expected_mode: ReferenceIndexListMode,
        expected_user_id: i64,
        rules: Vec<InteractionRuleEntity>,
        policy_denied: bool,
    }

    impl InteractionRuleGateway for ListGateway {
        fn list_index_for_filter(
            &self,
            filter: &ReferenceIndexListFilter,
        ) -> Result<Vec<InteractionRuleEntity>, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(filter.mode, self.expected_mode);
            assert_eq!(filter.user_id, self.expected_user_id);
            if self.policy_denied {
                Err(Box::new(PolicyPermissionDenied))
            } else {
                Ok(self.rules.clone())
            }
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<InteractionRuleEntity, Box<dyn std::error::Error + Send + Sync>> {
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

    struct SpyList {
        count: Option<usize>,
        failure: Option<ListFailure>,
    }

    impl InteractionRuleListOutputPort for SpyList {
        fn on_success(&mut self, rules: Vec<InteractionRuleEntity>) {
            self.count = Some(rules.len());
        }

        fn on_failure(&mut self, error: ListFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_rule() -> InteractionRuleEntity {
        InteractionRuleEntity::new(InteractionRuleEntityAttrs {
            id: Some(1),
            user_id: Some(1),
            rule_type: "continuous_cultivation".into(),
            source_group: "A".into(),
            target_group: "B".into(),
            impact_ratio: 1.0,
            is_reference: false,
            ..Default::default()
        })
        .unwrap()
    }

    // Ruby: test "call passes rules from gateway to output port on success"
    #[test]
    fn call_passes_rules_from_gateway_to_output_port_on_success() {
        let gateway = ListGateway {
            expected_mode: ReferenceIndexListMode::OwnedNonReference,
            expected_user_id: 1,
            rules: vec![sample_rule(), sample_rule()],
            policy_denied: false,
        };
        let mut output = SpyList {
            count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = InteractionRuleListInteractor::new(&mut output, 1, &gateway, &lookup);
        interactor.call().expect("handled");
        assert_eq!(output.count, Some(2));
    }

    // Ruby: test "forwards policy permission denied to on_failure as exception"
    #[test]
    fn forwards_policy_permission_denied_to_on_failure_as_exception() {
        let gateway = ListGateway {
            expected_mode: ReferenceIndexListMode::OwnedNonReference,
            expected_user_id: 1,
            rules: vec![],
            policy_denied: true,
        };
        let mut output = SpyList {
            count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = InteractionRuleListInteractor::new(&mut output, 1, &gateway, &lookup);
        interactor.call().expect("handled");
        assert!(matches!(
            output.failure,
            Some(ListFailure::Policy(PolicyPermissionDenied))
        ));
    }
