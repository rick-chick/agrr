// Tests for `interactors/masters_sunshine_requirement_create_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::crop::entities::SunshineRequirementEntity;
    use crate::shared::validation::ValidationErrors;
    use serde_json::json;

    struct ReqGw {
        exists: bool,
    }
    impl SunshineRequirementGateway for ReqGw {
        fn find_by_crop_stage_id(
            &self,
            stage_id: i64,
        ) -> Result<Option<SunshineRequirementEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            assert_eq!(stage_id, 2);
            Ok(if self.exists {
                Some(SunshineRequirementEntity::new(1, 2).unwrap())
            } else {
                None
            })
        }
    }

    struct CropGw {
        invalid: bool,
    }
    impl CropGateway for CropGw {
        fn create_sunshine_requirement(
            &self,
            stage_id: i64,
            _: SunshineRequirementUpdateInput,
        ) -> Result<SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(stage_id, 2);
            if self.invalid {
                let mut errors = ValidationErrors::new();
                errors.add("base", "must be numeric");
                return Err(Box::new(RecordInvalidError::new(
                    Some("x".into()),
                    Some(errors),
                )));
            }
            Ok(SunshineRequirementEntity::new(1, 2).unwrap())
        }
        fn list_index_for_filter(&self, _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn list_by_is_reference(&self, _: bool, _: Option<&str>) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_by_id(&self, _: i64) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_show_detail(&self, _: i64) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_record_with_stages(&self, _: i64) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn count_user_owned_non_reference_crops(&self, _: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_for_user(&self, _: &crate::shared::user::User, _: crate::shared::attr::AttrMap) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_for_user(&self, _: &crate::shared::user::User, _: i64, _: crate::shared::attr::AttrMap) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_delete_usage(&self, _: i64) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn soft_delete_with_undo(&self, _: &crate::shared::user::User, _: i64, _: i64, _: &str) -> Result<crate::crop::gateways::SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn list_by_crop_id(&self, _: i64) -> Result<Vec<crate::crop::entities::CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_crop_stage(&self, _: crate::crop::dtos::CropStageCreateInput) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_crop_stage(&self, _: i64, _: crate::crop::dtos::CropStageUpdateInput) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_thermal_requirement(&self, _: i64, _: crate::crop::dtos::ThermalRequirementUpdateInput) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_thermal_requirement(&self, _: i64, _: crate::crop::dtos::ThermalRequirementUpdateInput) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_thermal_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_sunshine_requirement(&self, _: i64, _: SunshineRequirementUpdateInput) -> Result<SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_sunshine_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_nutrient_requirement(&self, _: i64, _: crate::crop::dtos::NutrientRequirementUpdateInput) -> Result<crate::crop::entities::NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_nutrient_requirement(&self, _: i64, _: crate::crop::dtos::NutrientRequirementUpdateInput) -> Result<crate::crop::entities::NutrientRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_nutrient_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_temperature_requirement(&self, _: i64, _: crate::crop::dtos::TemperatureRequirementUpdateInput) -> Result<crate::crop::entities::TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_temperature_requirement(&self, _: i64, _: crate::crop::dtos::TemperatureRequirementUpdateInput) -> Result<crate::crop::entities::TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn delete_temperature_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
    }

    struct Spy {
        event: Option<&'static str>,
        errors: Option<Vec<String>>,
    }
    impl MastersSunshineRequirementOutputPort for Spy {
        fn on_show_success(&mut self, _: SunshineRequirementEntity) {}
        fn on_create_success(&mut self, _: SunshineRequirementEntity) {
            self.event = Some("create");
        }
        fn on_update_success(&mut self, _: SunshineRequirementEntity) {}
        fn on_destroy_success(&mut self) {}
        fn on_not_found(&mut self) {}
        fn on_already_exists(&mut self) {
            self.event = Some("already_exists");
        }
        fn on_validation_errors(&mut self, errors: Vec<String>) {
            self.event = Some("validation");
            self.errors = Some(errors);
        }
    }

    fn sample_input() -> SunshineRequirementUpdateInput {
        SunshineRequirementUpdateInput::new(1, 2, json!({"minimum_sunshine_hours": 5.0}))
    }

    // Ruby: test "creates when absent and reports success"
    #[test]
    fn creates_when_absent_and_reports_success() {
        let req = ReqGw { exists: false };
        let crop = CropGw { invalid: false };
        let mut out = Spy {
            event: None,
            errors: None,
        };
        let mut i =
            MastersSunshineRequirementCreateInteractor::new(&mut out, &crop, &req);
        i.call(sample_input()).unwrap();
        assert_eq!(out.event, Some("create"));
    }

    // Ruby: test "reports already exists when requirement present"
    #[test]
    fn reports_already_exists_when_requirement_present() {
        let req = ReqGw { exists: true };
        let crop = CropGw { invalid: false };
        let mut out = Spy {
            event: None,
            errors: None,
        };
        let mut i =
            MastersSunshineRequirementCreateInteractor::new(&mut out, &crop, &req);
        i.call(sample_input()).unwrap();
        assert_eq!(out.event, Some("already_exists"));
    }

    // Ruby: test "reports validation errors on RecordInvalid"
    #[test]
    fn reports_validation_errors_on_record_invalid() {
        let req = ReqGw { exists: false };
        let crop = CropGw { invalid: true };
        let mut out = Spy {
            event: None,
            errors: None,
        };
        let mut i =
            MastersSunshineRequirementCreateInteractor::new(&mut out, &crop, &req);
        i.call(SunshineRequirementUpdateInput::new(
            1,
            2,
            json!({"minimum_sunshine_hours": "bad"}),
        ))
        .unwrap();
        assert_eq!(out.event, Some("validation"));
        assert_eq!(out.errors, Some(vec!["must be numeric".into()]));
    }
