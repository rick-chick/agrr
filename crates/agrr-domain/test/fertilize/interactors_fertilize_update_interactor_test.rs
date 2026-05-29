// Tests for `interactors/fertilize_update_interactor.rs` (Ruby parity under test/domain/fertilize/).

    use crate::fertilize::entities::{FertilizeEntity, FertilizeEntityAttrs};
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
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct SpyOutput {
        success: Option<FertilizeEntity>,
        failure: Option<UpdateFailure>,
    }

    impl FertilizeUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: FertilizeEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: UpdateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_current(user_id: i64) -> FertilizeEntity {
        FertilizeEntity::new(FertilizeEntityAttrs {
            id: Some(1),
            user_id: Some(user_id),
            name: "F".into(),
            n: None,
            p: None,
            k: None,
            description: None,
            package_size: None,
            region: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid")
    }

    struct UpdateGateway {
        current: FertilizeEntity,
        updated: FertilizeEntity,
    }

    impl FertilizeGateway for UpdateGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.current.clone())
        }

        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.updated.clone())
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
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

    // Ruby: test "should update fertilize successfully for regular user"
    #[test]
    fn updates_successfully_for_regular_user() {
        let user_id = 1;
        let current = sample_current(user_id);
        let updated = FertilizeEntity::new(FertilizeEntityAttrs {
            name: "Updated Fertilize".into(),
            ..FertilizeEntityAttrs {
                id: Some(1),
                user_id: Some(user_id),
                name: "Updated Fertilize".into(),
                ..Default::default()
            }
        })
        .expect("valid");
        let gateway = UpdateGateway {
            current,
            updated: updated.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(user_id, false));
        let mut interactor = FertilizeUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = FertilizeUpdateInput {
            fertilize_id: 1,
            name: Some("Updated Fertilize".into()),
            n: Some(15.0),
            ..FertilizeUpdateInput::new(1)
        };
        interactor.call(input).expect("handled");
        assert_eq!(output.success.as_ref().map(|e| e.name.as_str()), Some("Updated Fertilize"));
    }

    // Ruby: test "should call on_failure with policy when interactor denies edit"
    #[test]
    fn denies_edit_for_other_user() {
        let user_id = 1;
        let current = sample_current(99);
        let gateway = UpdateGateway {
            current,
            updated: sample_current(user_id),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(user_id, false));
        let mut interactor = FertilizeUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = FertilizeUpdateInput {
            fertilize_id: 1,
            name: Some("x".into()),
            ..FertilizeUpdateInput::new(1)
        };
        interactor.call(input).expect("handled");
        assert!(matches!(
            output.failure,
            Some(UpdateFailure::Policy(PolicyPermissionDenied))
        ));
    }

    // Ruby: test "should raise error when non-admin user tries to change is_reference flag"
    #[test]
    fn non_admin_cannot_change_is_reference() {
        let user_id = 1;
        let current = sample_current(user_id);
        let gateway = UpdateGateway {
            current,
            updated: sample_current(user_id),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(user_id, false));
        let mut interactor = FertilizeUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = FertilizeUpdateInput {
            fertilize_id: 1,
            is_reference: Some(true),
            ..FertilizeUpdateInput::new(1)
        };
        interactor.call(input).expect("handled");
        match output.failure {
            Some(UpdateFailure::Fertilize(f)) => {
                assert_eq!(f.message, "fertilizes.flash.reference_flag_admin_only");
                assert_eq!(f.fertilize_id, Some(1));
            }
            other => panic!("expected Fertilize failure, got {other:?}"),
        }
    }
