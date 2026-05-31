// Tests for `interactors/agricultural_task_list_interactor.rs` (Ruby parity under test/domain/agricultural_task/).

    use crate::agricultural_task::dtos::AgriculturalTaskListInput;
    use crate::agricultural_task::entities::{AgriculturalTaskEntity, AgriculturalTaskEntityAttrs};
    use crate::agricultural_task::gateways::{AgriculturalTaskGateway, SoftDeleteUndoResult};
    use crate::agricultural_task::interactors::AgriculturalTaskListInteractor;
    use crate::agricultural_task::ports::{AgriculturalTaskListOutputPort, ListFailure};
    use crate::shared::exceptions::RecordNotFoundError;
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
    use crate::shared::user::User;
    use std::sync::{Arc, Mutex};

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    enum ListCall {
        None,
        Owned,
        All,
        Reference,
    }

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    enum GatewayError {
        None,
        Policy,
        NotFound,
    }

    struct ListGateway {
        call: Arc<Mutex<ListCall>>,
        tasks: Vec<AgriculturalTaskEntity>,
        error: GatewayError,
    }

    impl ListGateway {
        fn new(tasks: Vec<AgriculturalTaskEntity>) -> Self {
            Self {
                call: Arc::new(Mutex::new(ListCall::None)),
                tasks,
                error: GatewayError::None,
            }
        }
    }

    impl AgriculturalTaskGateway for ListGateway {
        fn list_user_owned_tasks(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            *self.call.lock().unwrap() = ListCall::Owned;
            match self.error {
                GatewayError::Policy => return Err(Box::new(PolicyPermissionDenied)),
                GatewayError::NotFound => return Err(Box::new(RecordNotFoundError)),
                GatewayError::None => {}
            }
            Ok(self.tasks.clone())
        }

        fn list_reference_tasks(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            *self.call.lock().unwrap() = ListCall::Reference;
            Ok(self.tasks.clone())
        }

        fn list_user_and_reference_tasks(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            *self.call.lock().unwrap() = ListCall::All;
            Ok(self.tasks.clone())
        }

        fn find_agricultural_task_show_detail(
            &self,
            _: i64,
        ) -> Result<
            crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
            Box<dyn std::error::Error + Send + Sync>,
        > {
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
        ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }

        fn find_by_user_id_and_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
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
        ) -> Result<SoftDeleteUndoResult, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        row_count: Option<usize>,
        failure: Option<ListFailure>,
    }

    impl AgriculturalTaskListOutputPort for SpyOutput {
        fn on_success(
            &mut self,
            rows: Vec<crate::shared::dtos::ReferencableListRow<AgriculturalTaskEntity>>,
        ) {
            self.row_count = Some(rows.len());
        }
        fn on_failure(&mut self, error: ListFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_task(id: i64, user_id: i64) -> AgriculturalTaskEntity {
        AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(id),
            user_id: Some(user_id),
            name: "task".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            region: None,
            task_type: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid")
    }

    // Ruby: test "non-admin: calls list_user_owned_tasks"
    #[test]
    fn non_admin_calls_list_user_owned_tasks() {
        let gateway = ListGateway::new(vec![sample_task(1, 1)]);
        let call = gateway.call.clone();
        let mut output = SpyOutput {
            row_count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor =
            AgriculturalTaskListInteractor::new(&mut output, 1, &gateway, &lookup);
        interactor.call(None).expect("handled");
        assert_eq!(*call.lock().unwrap(), ListCall::Owned);
        assert_eq!(output.row_count, Some(1));
    }

    // Ruby: test "admin with no filter (defaults to all): calls list_user_and_reference_tasks"
    #[test]
    fn admin_default_calls_list_user_and_reference_tasks() {
        let gateway = ListGateway::new(vec![]);
        let call = gateway.call.clone();
        let mut output = SpyOutput {
            row_count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(2, true));
        let mut interactor =
            AgriculturalTaskListInteractor::new(&mut output, 2, &gateway, &lookup);
        let input = AgriculturalTaskListInput::new(true, None, None);
        interactor.call(Some(input)).expect("handled");
        assert_eq!(*call.lock().unwrap(), ListCall::All);
        assert_eq!(output.row_count, Some(0));
    }

    // Ruby: test "admin filter=reference: calls list_reference_tasks"
    #[test]
    fn admin_filter_reference_calls_list_reference_tasks() {
        let gateway = ListGateway::new(vec![sample_task(9, 2)]);
        let call = gateway.call.clone();
        let mut output = SpyOutput {
            row_count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(2, true));
        let mut interactor =
            AgriculturalTaskListInteractor::new(&mut output, 2, &gateway, &lookup);
        let input = AgriculturalTaskListInput::new(true, Some("reference"), None);
        interactor.call(Some(input)).expect("handled");
        assert_eq!(*call.lock().unwrap(), ListCall::Reference);
        assert_eq!(output.row_count, Some(1));
    }

    // Ruby: test "forwards policy permission denied to on_failure as exception"
    #[test]
    fn forwards_policy_permission_denied_to_on_failure() {
        let mut gateway = ListGateway::new(vec![]);
        gateway.error = GatewayError::Policy;
        let mut output = SpyOutput {
            row_count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor =
            AgriculturalTaskListInteractor::new(&mut output, 1, &gateway, &lookup);
        interactor.call(None).expect("handled");
        assert!(matches!(
            output.failure,
            Some(ListFailure::Policy(PolicyPermissionDenied))
        ));
    }

    // Ruby: test "forwards RecordNotFound to on_failure as Error"
    #[test]
    fn forwards_record_not_found_to_on_failure_as_error() {
        let mut gateway = ListGateway::new(vec![]);
        gateway.error = GatewayError::NotFound;
        let mut output = SpyOutput {
            row_count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor =
            AgriculturalTaskListInteractor::new(&mut output, 1, &gateway, &lookup);
        interactor.call(None).expect("handled");
        match output.failure {
            Some(ListFailure::Error(e)) => assert_eq!(e.message, "Record not found"),
            other => panic!("expected Error, got {other:?}"),
        }
    }
