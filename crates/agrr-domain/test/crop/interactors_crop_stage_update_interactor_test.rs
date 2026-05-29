// Tests for `interactors/crop_stage_update_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::crop::entities::CropStageEntity;
    use serde_json::json;

    struct SpyOutput {
        success: Option<CropStageOutput>,
        failure: Option<CropStageUpdateFailure>,
    }

    impl CropStageUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, output: CropStageOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: CropStageUpdateFailure) {
            self.failure = Some(error);
        }
    }

    struct UpdateGateway {
        ok: Option<CropStageEntity>,
        invalid: bool,
        boom: bool,
    }

    impl CropGateway for UpdateGateway {
        fn update_crop_stage(
            &self,
            id: i64,
            input: CropStageUpdateInput,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(id, input.crop_stage_id);
            if self.boom {
                return Err("update failed".into());
            }
            if self.invalid {
                return Err(Box::new(RecordInvalidError::new(
                    Some("Name can't be blank".into()),
                    None,
                )));
            }
            Ok(self.ok.clone().unwrap())
        }
        fn list_index_for_filter(&self, _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(&self, _: i64) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_show_detail(&self, _: i64) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_record_with_stages(&self, _: i64) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn count_user_owned_non_reference_crops(&self, _: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_for_user(&self, _: &crate::shared::user::User, _: crate::shared::attr::AttrMap) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_for_user(&self, _: &crate::shared::user::User, _: i64, _: crate::shared::attr::AttrMap) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_delete_usage(&self, _: i64) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn soft_delete_with_undo(&self, _: &crate::shared::user::User, _: i64, _: i64, _: &str) -> Result<crate::crop::gateways::SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }

    fn list_by_crop_id(&self, _: i64) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_crop_stage(&self, _: crate::crop::dtos::CropStageCreateInput) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_thermal_requirement(&self, _: i64, _: crate::crop::dtos::ThermalRequirementUpdateInput) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_thermal_requirement(&self, _: i64, _: crate::crop::dtos::ThermalRequirementUpdateInput) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_thermal_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_temperature_requirement(&self, _: i64, _: crate::crop::dtos::TemperatureRequirementUpdateInput) -> Result<crate::crop::entities::TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_temperature_requirement(&self, _: i64, _: crate::crop::dtos::TemperatureRequirementUpdateInput) -> Result<crate::crop::entities::TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_temperature_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_sunshine_requirement(&self, _: i64, _: crate::crop::dtos::SunshineRequirementUpdateInput) -> Result<crate::crop::entities::SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_sunshine_requirement(&self, _: i64, _: crate::crop::dtos::SunshineRequirementUpdateInput) -> Result<crate::crop::entities::SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_sunshine_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_nutrient_requirement(&self, _: i64, _: crate::crop::dtos::NutrientRequirementUpdateInput) -> Result<crate::crop::entities::NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_nutrient_requirement(&self, _: i64, _: crate::crop::dtos::NutrientRequirementUpdateInput) -> Result<crate::crop::entities::NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_nutrient_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn masters_crop_agricultural_task_templates_index_rows(&self, _: i64) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_masters_crop_task_template_for_api(&self, _: i64, _: i64, _: serde_json::Value) -> Result<crate::crop::gateways::UpdateMastersCropTaskTemplateOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_masters_crop_task_template(&self, _: i64, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
    }

    // Ruby: test "calls on_success with updated crop stage when gateway succeeds"
    #[test]
    fn calls_on_success_with_updated_crop_stage_when_gateway_succeeds() {
        let stage = CropStageEntity::new(1, 1, "発芽", 2).unwrap();
        let gateway = UpdateGateway { ok: Some(stage.clone()), invalid: false, boom: false };
        let mut output = SpyOutput { success: None, failure: None };
        let mut interactor = CropStageUpdateInteractor::new(&mut output, &gateway);
        interactor.call(CropStageUpdateInput { crop_stage_id: 1, payload: json!({"name": "発芽", "order": 2}) }).unwrap();
        assert_eq!(output.success.unwrap().stage, stage);
    }

    // Ruby: test "calls on_failure with Error when gateway raises RecordInvalid"
    #[test]
    fn calls_on_failure_with_error_when_gateway_raises_record_invalid() {
        let gateway = UpdateGateway { ok: None, invalid: true, boom: false };
        let mut output = SpyOutput { success: None, failure: None };
        let mut interactor = CropStageUpdateInteractor::new(&mut output, &gateway);
        interactor.call(CropStageUpdateInput { crop_stage_id: 1, payload: json!({"name": "", "order": 2}) }).unwrap();
        assert!(matches!(output.failure, Some(CropStageUpdateFailure::Error(_))));
    }

    // Ruby: test "propagates StandardError when gateway raises"
    #[test]
    fn propagates_standard_error_when_gateway_raises() {
        let gateway = UpdateGateway { ok: None, invalid: false, boom: true };
        let mut output = SpyOutput { success: None, failure: None };
        let mut interactor = CropStageUpdateInteractor::new(&mut output, &gateway);
        let err = interactor.call(CropStageUpdateInput { crop_stage_id: 1, payload: json!({"name": "発芽", "order": 2}) }).unwrap_err();
        assert!(err.to_string().contains("update failed"));
    }
