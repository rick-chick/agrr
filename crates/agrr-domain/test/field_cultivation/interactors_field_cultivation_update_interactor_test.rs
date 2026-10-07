// Tests for `interactors/field_cultivation_update_interactor.rs`.

    use crate::field_cultivation::dtos::{
        FieldCultivationApiUpdateInput, FieldCultivationApiUpdateOutput,
        FieldCultivationPlanAccessSnapshot,
    };
    use crate::field_cultivation::gateways::FieldCultivationGateway;
    use crate::field_cultivation::ports::{
        FieldCultivationApiUpdateOutputPort, FieldCultivationUpdateFailure,
    };
    use std::sync::atomic::{AtomicU32, Ordering};

    struct StubGateway {
        access: FieldCultivationPlanAccessSnapshot,
        update_calls: AtomicU32,
    }

    impl FieldCultivationGateway for StubGateway {
        fn find_plan_access_snapshot_by_field_cultivation_id(
            &self,
            _: i64,
        ) -> Result<FieldCultivationPlanAccessSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(self.access.clone())
        }

        fn find_api_summary_by_field_cultivation_id(
            &self,
            _: i64,
        ) -> Result<
            crate::field_cultivation::dtos::FieldCultivationApiSummary,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn update_field_cultivation_schedule(
            &self,
            _: i64,
            _: &str,
            _: &str,
            _: Option<i32>,
        ) -> Result<FieldCultivationApiUpdateOutput, Box<dyn std::error::Error + Send + Sync>>
        {
            self.update_calls.fetch_add(1, Ordering::SeqCst);
            Ok(FieldCultivationApiUpdateOutput {
                field_cultivation_id: 1,
                start_date: "2026-05-01".into(),
                completion_date: "2026-09-30".into(),
                cultivation_days: None,
                message: None,
            })
        }
    }

    struct NoopTranslator;
    impl crate::shared::ports::translator_port::TranslatorPort for NoopTranslator {
        fn translate(
            &self,
            key: &str,
            _options: &crate::shared::ports::translator_port::TranslateOptions,
        ) -> String {
            key.to_string()
        }

        fn localize(
            &self,
            _date: time::Date,
            _format: Option<&str>,
            _options: &crate::shared::ports::translator_port::TranslateOptions,
        ) -> String {
            String::new()
        }
    }

    struct StubLookup;
    impl crate::shared::gateways::user_lookup_gateway::UserLookupGateway for StubLookup {
        fn find(&self, id: i64) -> crate::shared::user::User {
            crate::shared::user::User::new(id, false)
        }
    }

    struct SpyOutput {
        failure: Option<FieldCultivationUpdateFailure>,
        success: bool,
    }

    impl FieldCultivationApiUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, _: FieldCultivationApiUpdateOutput) {
            self.success = true;
        }

        fn on_failure(&mut self, failure: FieldCultivationUpdateFailure) {
            self.failure = Some(failure);
        }
    }

    #[test]
    fn private_route_rejects_update_for_public_plan_non_owner() {
        let access = FieldCultivationPlanAccessSnapshot::new(42, true, false, Some(5), None);
        let gateway = StubGateway {
            access,
            update_calls: AtomicU32::new(0),
        };
        let mut output = SpyOutput {
            failure: None,
            success: false,
        };
        let mut interactor = FieldCultivationUpdateInteractor::with_user(
            &mut output,
            &gateway,
            99,
            &StubLookup,
            Some(&NoopTranslator),
        );
        let input = FieldCultivationApiUpdateInput {
            field_cultivation_id: 42,
            start_date: "2026-05-01".into(),
            completion_date: "2026-09-30".into(),
            public_plan: false,
            public_session_id: None,
        };
        interactor.call(input).expect("call");
        assert_eq!(0, gateway.update_calls.load(Ordering::SeqCst));
        assert!(!output.success);
        let failure = output.failure.expect("forbidden failure");
        match failure {
            FieldCultivationUpdateFailure::Message(err) => {
                assert_eq!("Forbidden", err.message);
            }
            _ => panic!("expected forbidden message"),
        }
    }
