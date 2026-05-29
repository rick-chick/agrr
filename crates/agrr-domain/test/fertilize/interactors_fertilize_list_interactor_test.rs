// Tests for `interactors/fertilize_list_interactor.rs` (Ruby parity under test/domain/fertilize/).

    use crate::fertilize::entities::{FertilizeEntity, FertilizeEntityAttrs};
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
        entities: Vec<FertilizeEntity>,
    }

    impl FertilizeGateway for ListGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_index_for_filter(
            &self,
            filter: &ReferenceIndexListFilter,
        ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(filter.mode, ReferenceIndexListMode::OwnedNonReference);
            assert_eq!(filter.user_id, 42);
            Ok(self.entities.clone())
        }

        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn crate::shared::ports::TranslatorPort,
        ) -> Result<
            crate::fertilize::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        count: Option<usize>,
        failure: Option<ListFailure>,
    }

    impl FertilizeListOutputPort for SpyOutput {
        fn on_success(&mut self, rows: Vec<crate::shared::dtos::ReferencableListRow<FertilizeEntity>>) {
            self.count = Some(rows.len());
        }
        fn on_failure(&mut self, error: ListFailure) {
            self.failure = Some(error);
        }
    }

    fn entity(user_id: i64) -> FertilizeEntity {
        FertilizeEntity::new(FertilizeEntityAttrs {
            id: Some(1),
            user_id: Some(user_id),
            name: "F".into(),
            ..Default::default()
        })
        .expect("valid")
    }

    // Ruby: test "call passes fertilize entities to output port"
    #[test]
    fn passes_entities_to_output_port() {
        let gateway = ListGateway {
            entities: vec![entity(42), entity(42)],
        };
        let mut output = SpyOutput {
            count: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(42, false));
        let mut interactor =
            FertilizeListInteractor::new(&mut output, 42, &gateway, &lookup);
        interactor.call().expect("handled");
        assert_eq!(output.count, Some(2));
    }
