// Tests for `interactors/field_list_interactor.rs` (Ruby parity under test/domain/field/).

    use crate::field::entities::FieldEntity;
    use crate::field::results::{FarmFieldsList, FarmRecord};
    use crate::shared::policies::farm_policy::FarmRecordAccessPolicy;
    use crate::shared::user::User;

    struct StubLookup {
        user: User,
    }

    impl UserLookupGateway for StubLookup {
        fn find(&self, _user_id: i64) -> User {
            self.user.clone()
        }
    }

    enum FarmFieldsListBehavior {
        Return(FarmFieldsList),
        NotFound,
        PolicyDenied,
    }

    struct StubGateway {
        behavior: FarmFieldsListBehavior,
    }

    impl FieldGateway for StubGateway {
        fn get_total_area_by_farm_id(&self, _: i64) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
            Ok(0.0)
        }

        fn farm_fields_list(
            &self,
            _: i64,
        ) -> Result<FarmFieldsList, Box<dyn std::error::Error + Send + Sync>> {
            match &self.behavior {
                FarmFieldsListBehavior::Return(v) => Ok(v.clone()),
                FarmFieldsListBehavior::NotFound => Err(Box::new(RecordNotFoundError)),
                FarmFieldsListBehavior::PolicyDenied => Err(Box::new(PolicyPermissionDenied)),
            }
        }

        fn field_with_farm(
            &self,
            _: i64,
        ) -> Result<crate::field::results::FieldWithFarm, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }

        fn create(
            &self,
            _: &crate::field::dtos::FieldCreateInput,
            _: i64,
            _: &crate::shared::reference_record_access_filter::ReferenceRecordAccessFilter<
                FarmRecordAccessPolicy,
            >,
        ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update(
            &self,
            _: i64,
            _: &crate::field::dtos::FieldUpdateInput,
        ) -> Result<FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn delete(&self, _: i64) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        success: Option<FarmFieldsList>,
        failure: Option<ListFailure>,
    }

    impl FieldListOutputPort for SpyOutput {
        fn on_success(&mut self, result: FarmFieldsList) {
            self.success = Some(result);
        }

        fn on_failure(&mut self, error: ListFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "call passes FarmFieldsList to output port on success"
    #[test]
    fn call_passes_farm_fields_list_on_success() {
        let farm = FarmRecord {
            id: 1,
            name: "F".into(),
            user_id: Some(9),
            is_reference: false,
            latitude: None,
            longitude: None,
            region: None,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
        };
        let field = FieldEntity {
            id: 2,
            farm_id: 1,
            user_id: Some(9),
            name: "North".into(),
            description: None,
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-01T00:00:00Z".into()),
            area: None,
            daily_fixed_cost: None,
            region: None,
        };
        let list = FarmFieldsList::new(farm.clone(), vec![field.clone()]);
        let gateway = StubGateway {
            behavior: FarmFieldsListBehavior::Return(list),
        };
        let lookup = StubLookup {
            user: User::new(9, false),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = FieldListInteractor::new(&mut output, 20, &gateway, &lookup);
        interactor.call(10).unwrap();
        let received = output.success.unwrap();
        assert_eq!(received.farm, farm);
        assert_eq!(received.fields, vec![field]);
    }

    // Ruby: test "call forwards RecordNotFound to on_failure as Error"
    #[test]
    fn call_forwards_record_not_found_as_error() {
        let gateway = StubGateway {
            behavior: FarmFieldsListBehavior::NotFound,
        };
        let lookup = StubLookup {
            user: User::new(9, false),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = FieldListInteractor::new(&mut output, 20, &gateway, &lookup);
        interactor.call(10).unwrap();
        match output.failure.unwrap() {
            ListFailure::Error(e) => assert_eq!(e.message, "record not found"),
            other => panic!("unexpected failure: {other:?}"),
        }
    }

    // Ruby: test "call forwards policy permission denied to on_failure as exception"
    #[test]
    fn call_forwards_policy_permission_denied() {
        let gateway = StubGateway {
            behavior: FarmFieldsListBehavior::PolicyDenied,
        };
        let lookup = StubLookup {
            user: User::new(9, false),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = FieldListInteractor::new(&mut output, 20, &gateway, &lookup);
        interactor.call(10).unwrap();
        assert!(matches!(
            output.failure,
            Some(ListFailure::Policy(PolicyPermissionDenied))
        ));
    }
