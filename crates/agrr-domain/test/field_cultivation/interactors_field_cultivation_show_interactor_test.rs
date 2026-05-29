// Tests for `interactors/field_cultivation_show_interactor.rs` (Ruby parity under test/domain/field_cultivation/).

    use crate::field_cultivation::dtos::{
        FieldCultivationApiSummary, FieldCultivationPlanAccessSnapshot,
    };
    use time::macros::date;

    struct StubGateway {
        access: FieldCultivationPlanAccessSnapshot,
        summary: Option<FieldCultivationApiSummary>,
        fail_not_found: bool,
    }

    impl FieldCultivationGateway for StubGateway {
        fn find_plan_access_snapshot_by_field_cultivation_id(
            &self,
            _: i64,
        ) -> Result<FieldCultivationPlanAccessSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            if self.fail_not_found {
                return Err(Box::new(RecordNotFoundError));
            }
            Ok(self.access.clone())
        }

        fn find_api_summary_by_field_cultivation_id(
            &self,
            _: i64,
        ) -> Result<FieldCultivationApiSummary, Box<dyn std::error::Error + Send + Sync>> {
            if self.fail_not_found {
                return Err(Box::new(RecordNotFoundError));
            }
            Ok(self.summary.clone().unwrap())
        }

        fn update_field_cultivation_schedule(
            &self,
            _: i64,
            _: &str,
            _: &str,
            _: Option<i32>,
        ) -> Result<
            crate::field_cultivation::dtos::FieldCultivationApiUpdateOutput,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
    }

    struct StubLookup;
    impl UserLookupGateway for StubLookup {
        fn find(&self, id: i64) -> crate::shared::user::User {
            crate::shared::user::User::new(id, false)
        }
    }

    struct SpyOutput {
        success: Option<FieldCultivationApiSummary>,
        failure: Option<Error>,
    }

    impl FieldCultivationApiShowOutputPort for SpyOutput {
        fn on_success(&mut self, dto: FieldCultivationApiSummary) {
            self.success = Some(dto);
        }
        fn on_failure(&mut self, error: Error) {
            self.failure = Some(error);
        }
    }

    #[test]
    fn calls_on_success_when_gateway_returns_summary() {
        let summary = FieldCultivationApiSummary {
            id: 42,
            field_name: "F".into(),
            crop_name: "C".into(),
            area: 1.0,
            start_date: date!(2026 - 01 - 01),
            completion_date: date!(2026 - 01 - 02),
            cultivation_days: 2,
            estimated_cost: 3.0,
            gdd: Some(4.0),
            status: "completed".into(),
        };
        let gateway = StubGateway {
            access: FieldCultivationPlanAccessSnapshot::new(42, true, false, None),
            summary: Some(summary.clone()),
            fail_not_found: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor =
            FieldCultivationShowInteractor::<_, _, StubLookup>::new(&mut output, &gateway);
        interactor.call(42).unwrap();
        assert_eq!(output.success.unwrap(), summary);
    }

    #[test]
    fn forbidden_for_private_plan_non_owner() {
        let gateway = StubGateway {
            access: FieldCultivationPlanAccessSnapshot::new(7, false, true, Some(99)),
            summary: Some(FieldCultivationApiSummary {
                id: 7,
                field_name: "F".into(),
                crop_name: "C".into(),
                area: 1.0,
                start_date: date!(2026 - 01 - 01),
                completion_date: date!(2026 - 01 - 02),
                cultivation_days: 2,
                estimated_cost: 3.0,
                gdd: None,
                status: "completed".into(),
            }),
            fail_not_found: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup;
        let mut interactor =
            FieldCultivationShowInteractor::with_user(&mut output, &gateway, 1, &lookup);
        interactor.call(7).unwrap();
        assert_eq!(output.failure.unwrap().message, "Forbidden");
    }
