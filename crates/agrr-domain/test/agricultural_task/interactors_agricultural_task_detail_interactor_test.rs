// Tests for `interactors/agricultural_task_detail_interactor.rs` (Ruby parity under test/domain/agricultural_task/).

    use crate::agricultural_task::dtos::AgriculturalTaskShowDetail;
    use crate::agricultural_task::entities::{AgriculturalTaskEntity, AgriculturalTaskEntityAttrs};
    use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct DetailGateway {
        detail: AgriculturalTaskShowDetail,
    }

    impl AgriculturalTaskGateway for DetailGateway {
        fn find_agricultural_task_show_detail(
            &self,
            _: i64,
        ) -> Result<AgriculturalTaskShowDetail, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.detail.clone())
        }

        fn list_user_owned_tasks(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_reference_tasks(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_user_and_reference_tasks(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_reference_and_name(
            &self,
            _: &str,
        ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_user_id_and_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn create(
            &self,
            _: crate::shared::attr::AttrMap,
        ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update(
            &self,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn within_transaction<F, T>(&self, block: F) -> T
        where
            F: FnOnce() -> T,
        {
            block()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::agricultural_task::gateways::SoftDeleteUndoResult,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
    }

    struct SpyDetail {
        success: Option<i64>,
        failure: Option<DetailFailure>,
    }

    impl AgriculturalTaskDetailOutputPort for SpyDetail {
        fn on_success(&mut self, dto: AgriculturalTaskDetailOutput) {
            self.success = dto.task.id;
        }

        fn on_failure(&mut self, error: DetailFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_task(user_id: i64) -> AgriculturalTaskEntity {
        AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(22),
            user_id: Some(user_id),
            name: "作業".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            region: None,
            task_type: None,
            is_reference: false,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        })
        .expect("valid")
    }

    // Ruby: test "calls on_success with detail dto when read gateway returns wire"
    #[test]
    fn calls_on_success_with_detail_dto_when_read_gateway_returns_wire() {
        let gateway = DetailGateway {
            detail: AgriculturalTaskShowDetail {
                task: sample_task(10),
                associated_crops: vec![],
            },
        };
        let mut output = SpyDetail {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor =
            AgriculturalTaskDetailInteractor::new(&mut output, 10, &gateway, &lookup);
        interactor.call(22).expect("handled");
        assert_eq!(output.success, Some(22));
        assert!(output.failure.is_none());
    }

    // Ruby: test "calls on_failure with policy exception when permission is denied"
    #[test]
    fn calls_on_failure_with_policy_exception_when_permission_is_denied() {
        let gateway = DetailGateway {
            detail: AgriculturalTaskShowDetail {
                task: sample_task(99),
                associated_crops: vec![],
            },
        };
        let mut output = SpyDetail {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor =
            AgriculturalTaskDetailInteractor::new(&mut output, 10, &gateway, &lookup);
        interactor.call(22).expect("handled");
        assert!(output.success.is_none());
        assert!(matches!(
            output.failure,
            Some(DetailFailure::Policy(PolicyPermissionDenied))
        ));
    }
