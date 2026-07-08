// Tests for `interactors/masters_thermal_requirement_update_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::crop::entities::ThermalRequirementEntity;
    use serde_json::json;

    struct ReqGw {
        exists: bool,
    }
    impl ThermalRequirementGateway for ReqGw {
        fn find_by_crop_stage_id(
            &self,
            stage_id: i64,
        ) -> Result<Option<ThermalRequirementEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            assert_eq!(stage_id, 2);
            Ok(if self.exists {
                Some(ThermalRequirementEntity::new(1, 2, rust_decimal::Decimal::from(200)).unwrap())
            } else {
                None
            })
        }
    }

    struct CropGw;
    impl CropGateway for CropGw {
        fn update_thermal_requirement(
            &self,
            stage_id: i64,
            _: ThermalRequirementUpdateInput,
        ) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(stage_id, 2);
            Ok(ThermalRequirementEntity::new(1, 2, rust_decimal::Decimal::from(200)).unwrap())
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
        fn delete_thermal_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_sunshine_requirement(&self, _: i64, _: crate::crop::dtos::SunshineRequirementUpdateInput) -> Result<crate::crop::entities::SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_sunshine_requirement(&self, _: i64, _: crate::crop::dtos::SunshineRequirementUpdateInput) -> Result<crate::crop::entities::SunshineRequirementEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
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
    }
    impl MastersThermalRequirementOutputPort for Spy {
        fn on_show_success(&mut self, _: ThermalRequirementEntity) {}
        fn on_create_success(&mut self, _: ThermalRequirementEntity) {}
        fn on_update_success(&mut self, _: ThermalRequirementEntity) {
            self.event = Some("update");
        }
        fn on_destroy_success(&mut self) {}
        fn on_not_found(&mut self) {
            self.event = Some("not_found");
        }
        fn on_already_exists(&mut self) {}
        fn on_validation_errors(&mut self, _: Vec<String>) {}
    }

    // Ruby: test "updates when present"
    #[test]
    fn updates_when_present() {
        let req = ReqGw { exists: true };
        let crop = CropGw;
        let mut out = Spy { event: None };
        let mut i = MastersThermalRequirementUpdateInteractor::new(&mut out, &crop, &req);
        i.call(ThermalRequirementUpdateInput::new(
            1,
            2,
            json!({"required_gdd": 250.0}),
        ))
        .unwrap();
        assert_eq!(out.event, Some("update"));
    }

    // Ruby: test "not found when missing before update"
    #[test]
    fn not_found_when_missing_before_update() {
        let req = ReqGw { exists: false };
        let crop = CropGw;
        let mut out = Spy { event: None };
        let mut i = MastersThermalRequirementUpdateInteractor::new(&mut out, &crop, &req);
        i.call(ThermalRequirementUpdateInput::new(1, 2, json!({})))
            .unwrap();
        assert_eq!(out.event, Some("not_found"));
    }
