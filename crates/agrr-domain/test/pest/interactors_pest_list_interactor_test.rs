// Tests for `interactors/pest_list_interactor.rs` (Ruby parity under test/domain/pest/).

    use crate::pest::entities::{PestEntity, PestEntityAttrs};
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
        entities: Vec<PestEntity>,
        fail: bool,
    }

    impl PestGateway for ListGateway {

        fn list_pests_for_crop_filtered(
            &self,
            _: i64,
            _: &[i64],
            _: crate::pest::gateways::CropPestListOrder,
        ) -> Result<Vec<crate::pest::entities::PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &crate::shared::user::User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            filter: &ReferenceIndexListFilter,
        ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(filter.mode, self.expected_mode);
            assert_eq!(filter.user_id, self.expected_user_id);
            if self.fail {
                Err(Box::new(RecordInvalidError::new(Some("x".into()), None)))
            } else {
                Ok(self.entities.clone())
            }
        }
        fn find_pest_show_detail(
            &self,
            _: i64,
        ) -> Result<crate::pest::dtos::PestShowDetail, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::pest::dtos::PestDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: i64,
            _: &dyn crate::shared::ports::TranslatorPort,
        ) -> Result<
            crate::pest::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        count: Option<usize>,
        failure: Option<ListFailure>,
    }

    impl PestListOutputPort for SpyOutput {
        fn on_success(
            &mut self,
            rows: Vec<crate::shared::dtos::ReferencableListRow<PestEntity>>,
        ) {
            self.count = Some(rows.len());
        }
        fn on_failure(&mut self, error: ListFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_pest(id: i64, user_id: i64) -> PestEntity {
        PestEntity::new(PestEntityAttrs {
            id: Some(id),
            user_id: Some(user_id),
            name: format!("P{id}"),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid")
    }

    // Ruby: test "call loads pests using policy-built filter for regular user"
    #[test]
    fn call_loads_pests_for_regular_user() {
        let gateway = ListGateway {
            expected_mode: ReferenceIndexListMode::OwnedNonReference,
            expected_user_id: 42,
            entities: vec![sample_pest(1, 42), sample_pest(2, 42)],
            fail: false,
        };
        let mut output = SpyOutput {
            count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(42, false));
        let mut interactor = PestListInteractor::new(&mut output, 42, &gateway, &lookup);
        interactor.call().expect("handled");
        assert_eq!(output.count, Some(2));
    }

    // Ruby: test "call loads pests using policy-built filter for admin"
    #[test]
    fn call_loads_pests_for_admin() {
        let gateway = ListGateway {
            expected_mode: ReferenceIndexListMode::ReferenceOrOwned,
            expected_user_id: 99,
            entities: vec![],
            fail: false,
        };
        let mut output = SpyOutput {
            count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(99, true));
        let mut interactor = PestListInteractor::new(&mut output, 99, &gateway, &lookup);
        interactor.call().expect("handled");
        assert_eq!(output.count, Some(0));
    }

    // Ruby: test "call maps RecordInvalid to failure Error"
    #[test]
    fn call_maps_record_invalid_to_failure_error() {
        let gateway = ListGateway {
            expected_mode: ReferenceIndexListMode::OwnedNonReference,
            expected_user_id: 1,
            entities: vec![],
            fail: true,
        };
        let mut output = SpyOutput {
            count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = PestListInteractor::new(&mut output, 1, &gateway, &lookup);
        interactor.call().expect("handled");
        match output.failure {
            Some(ListFailure::Error(err)) => assert!(err.message.contains("x")),
            other => panic!("expected Error failure, got {other:?}"),
        }
    }
