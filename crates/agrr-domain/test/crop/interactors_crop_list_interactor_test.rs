// Tests for `interactors/crop_list_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::crop::entities::CropEntity;
    use crate::crop::gateways::CropGateway;
    use crate::crop::ports::CropListOutputPort;
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

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
        entities: Vec<CropEntity>,
        fail_not_found: bool,
    }

    impl CropGateway for ListGateway {
        fn list_index_for_filter(
            &self,
            filter: &ReferenceIndexListFilter,
        ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(filter.mode, self.expected_mode);
            assert_eq!(filter.user_id, self.expected_user_id);
            if self.fail_not_found {
                return Err(Box::new(RecordNotFoundError));
            }
            Ok(self.entities.clone())
        }

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_crop_show_detail(
            &self,
            _: i64,
        ) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_crop_record_with_stages(
            &self,
            _: i64,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn count_user_owned_non_reference_crops(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::crop::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

    fn list_by_crop_id(
            &self,
            _: i64,
        ) -> Result<Vec<crate::crop::entities::CropStageEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn create_crop_stage(
            &self,
            _: crate::crop::dtos::CropStageCreateInput,
        ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn update_crop_stage(
            &self,
            _: i64,
            _: crate::crop::dtos::CropStageUpdateInput,
        ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_thermal_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::ThermalRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::ThermalRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_thermal_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::ThermalRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::ThermalRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_thermal_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_temperature_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::TemperatureRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::TemperatureRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_temperature_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::TemperatureRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::TemperatureRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_temperature_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_sunshine_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::SunshineRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::SunshineRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_sunshine_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::SunshineRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::SunshineRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_sunshine_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_nutrient_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::NutrientRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::NutrientRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_nutrient_requirement(
            &self,
            _: i64,
            _: crate::crop::dtos::NutrientRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::NutrientRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_nutrient_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn masters_crop_agricultural_task_templates_index_rows(
            &self,
            _: i64,
        ) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_masters_crop_task_template_for_api(
            &self,
            _: i64,
            _: i64,
            _: serde_json::Value,
        ) -> Result<
            crate::crop::gateways::UpdateMastersCropTaskTemplateOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_masters_crop_task_template(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        success: Option<Vec<crate::shared::dtos::ReferencableListRow<CropEntity>>>,
        failure: Option<ListFailure>,
    }

    impl CropListOutputPort for SpyOutput {
        fn on_success(&mut self, rows: Vec<crate::shared::dtos::ReferencableListRow<CropEntity>>) {
            self.success = Some(rows);
        }
        fn on_failure(&mut self, error: ListFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_crop(id: i64, user_id: i64) -> CropEntity {
        CropEntity {
            id,
            user_id: Some(user_id),
            name: "C".into(),
            variety: None,
            is_reference: false,
            area_per_unit: None,
            revenue_per_area: None,
            region: None,
            groups: vec![],
            created_at: None,
            updated_at: None,
        }
    }

    // Ruby: test "call loads crops using policy-built filter for regular user"
    #[test]
    fn call_loads_crops_using_policy_built_filter_for_regular_user() {
        let entities = vec![sample_crop(1, 42), sample_crop(2, 42)];
        let gateway = ListGateway {
            expected_mode: ReferenceIndexListMode::OwnedNonReference,
            expected_user_id: 42,
            entities: entities.clone(),
            fail_not_found: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup_1 = StubLookup(User::new(42, false));
        let mut interactor =
            CropListInteractor::new(&mut output, 42, &gateway, &user_lookup_1);
        interactor.call().unwrap();
        let rows = output.success.unwrap();
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].record.id, entities[0].id);
    }

    // Ruby: test "call loads crops using policy-built filter for admin"
    #[test]
    fn call_loads_crops_using_policy_built_filter_for_admin() {
        let gateway = ListGateway {
            expected_mode: ReferenceIndexListMode::ReferenceOrOwned,
            expected_user_id: 99,
            entities: vec![],
            fail_not_found: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup_2 = StubLookup(User::new(99, true));
        let mut interactor =
            CropListInteractor::new(&mut output, 99, &gateway, &user_lookup_2);
        interactor.call().unwrap();
        assert_eq!(output.success, Some(vec![]));
    }

    // Ruby: test "call maps RecordNotFound to failure Error"
    #[test]
    fn call_maps_record_not_found_to_failure_error() {
        let gateway = ListGateway {
            expected_mode: ReferenceIndexListMode::OwnedNonReference,
            expected_user_id: 1,
            entities: vec![],
            fail_not_found: true,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup_3 = StubLookup(User::new(1, false));
        let mut interactor =
            CropListInteractor::new(&mut output, 1, &gateway, &user_lookup_3);
        interactor.call().unwrap();
        match output.failure {
            Some(ListFailure::Error(e)) => assert!(e.message.contains("record not found")),
            other => panic!("expected Error failure, got {other:?}"),
        }
    }
