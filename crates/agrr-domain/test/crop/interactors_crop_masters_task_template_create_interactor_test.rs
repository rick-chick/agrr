// Tests for `interactors/crop_masters_task_template_create_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::agricultural_task::entities::{AgriculturalTaskEntity, AgriculturalTaskEntityAttrs};
    use crate::crop::entities::{CropEntity, CropTaskTemplateEntity};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct Spy {
        success: bool,
        failure: Option<MastersCropTaskTemplateCreateFailureReason>,
    }

    impl CropMastersTaskTemplateCreateOutputPort for Spy {
        fn on_success(&mut self, _: crate::crop::dtos::MastersCropTaskTemplate) {
            self.success = true;
        }
        fn on_failure(&mut self, failure: MastersCropTaskTemplateCreateFailure) {
            self.failure = Some(failure.reason);
        }
    }

    fn crop() -> CropEntity {
        CropEntity {
            id: 2,
            user_id: Some(1),
            name: "Foo".into(),
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

    fn task() -> AgriculturalTaskEntity {
        AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(3),
            user_id: Some(1),
            name: "T".into(),
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
        .unwrap()
    }

    struct SuccessGw;
    impl CropGateway for SuccessGw {

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
            Ok(crop())
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_crop_show_detail(
            &self,
            _: i64,
        ) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> {
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
        ) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
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
        ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_crop_stage(
            &self,
            _: i64,
            _: crate::crop::dtos::CropStageUpdateInput,
        ) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
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

    struct TemplateGw;
    impl CropMastersTaskTemplateGateway for TemplateGw {
        fn find_by_agricultural_task_id_and_crop_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<CropTaskTemplateEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(None)
        }
        fn create_detail(
            &self,
            _: i64,
            _: i64,
            _: crate::crop::dtos::CropTaskTemplatePersistAttributes,
        ) -> Result<CropTaskTemplateEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(CropTaskTemplateEntity {
                id: 10,
                crop_id: 2,
                agricultural_task_id: 3,
                name: "T".into(),
                description: None,
                time_per_sqm: None,
                weather_dependency: None,
                required_tools: vec![],
                skill_level: None,
                created_at: None,
                updated_at: None,
            })
        }
    }

    struct TaskGw;
    impl AgriculturalTaskGateway for TaskGw {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(task())
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
        fn find_agricultural_task_show_detail(
            &self,
            _: i64,
        ) -> Result<
            crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
            Box<dyn std::error::Error + Send + Sync>,
        > {
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

    // Ruby: test "should create association successfully"
    #[test]
    fn should_create_association_successfully() {
        let mut out = Spy {
            success: false,
            failure: None,
        };
        let user_lookup_1 = StubLookup(User::new(1, false));
        let mut i = CropMastersTaskTemplateCreateInteractor::new(
            &mut out,
            &SuccessGw,
            &TemplateGw,
            &user_lookup_1,
            &TaskGw,
        );
        i.call(MastersCropTaskTemplateCreateInput::new(1, 2, Some(3)))
            .unwrap();
        assert!(out.success);
    }

    // Ruby: test "should return failure when agricultural_task_id missing"
    #[test]
    fn should_return_failure_when_agricultural_task_id_missing() {
        let mut out = Spy {
            success: false,
            failure: None,
        };
        let user_lookup_1 = StubLookup(User::new(1, false));
        let mut i = CropMastersTaskTemplateCreateInteractor::new(
            &mut out,
            &SuccessGw,
            &TemplateGw,
            &user_lookup_1,
            &TaskGw,
        );
        i.call(MastersCropTaskTemplateCreateInput::new(1, 2, None))
            .unwrap();
        assert_eq!(
            out.failure,
            Some(MastersCropTaskTemplateCreateFailureReason::MissingAgriculturalTaskId)
        );
    }
