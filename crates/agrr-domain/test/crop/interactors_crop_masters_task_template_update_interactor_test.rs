// Tests for `interactors/crop_masters_task_template_update_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::crop::entities::CropEntity;
    use crate::shared::user::User;
    struct L(User); impl UserLookupGateway for L { fn find(&self, _: i64) -> User { self.0 } }
    struct O { ok: bool, fail: Option<MastersCropTaskTemplateMastersFailureReason> }
    impl CropMastersTaskTemplateUpdateOutputPort for O {
        fn on_success(&mut self, _: serde_json::Value) { self.ok = true; }
        fn on_failure(&mut self, f: MastersCropTaskTemplateMastersFailure) { self.fail = Some(f.reason); }
    }
    struct G { row: serde_json::Value, mode: &'static str }
    impl CropGateway for G {

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(CropEntity { id: 1, user_id: Some(1), name: "c".into(), variety: None, is_reference: false, area_per_unit: None, revenue_per_area: None, region: None, groups: vec![], created_at: None, updated_at: None })
        }
        fn update_masters_crop_task_template_for_api(&self, _: i64, _: i64, _: serde_json::Value) -> Result<UpdateMastersCropTaskTemplateOutcome, Box<dyn std::error::Error + Send + Sync>> {
            match self.mode {
                "ok" => Ok(UpdateMastersCropTaskTemplateOutcome::Ok { row: self.row.clone() }),
                "val" => Ok(UpdateMastersCropTaskTemplateOutcome::ValidationFailed { errors: vec!["e".into()] }),
                _ => Err(Box::new(RecordNotFoundError)),
            }
        }
        fn list_index_for_filter(&self, _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_show_detail(&self, _: i64) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_record_with_stages(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn count_user_owned_non_reference_crops(&self, _: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_for_user(&self, _: &User, _: crate::shared::attr::AttrMap) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_for_user(&self, _: &User, _: i64, _: crate::shared::attr::AttrMap) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_delete_usage(&self, _: i64) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn soft_delete_with_undo(&self, _: &User, _: i64, _: i64, _: &str) -> Result<crate::crop::gateways::SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }

    fn list_by_crop_id(&self, _: i64) -> Result<Vec<crate::crop::entities::CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_crop_stage(&self, _: crate::crop::dtos::CropStageCreateInput) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn update_crop_stage(&self, _: i64, _: crate::crop::dtos::CropStageUpdateInput) -> Result<crate::crop::entities::CropStageEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
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
        fn delete_masters_crop_task_template(&self, _: i64, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
    }
    // Ruby: test "should return updated row successfully"
    #[test] fn updated_row() {
        let mut o = O { ok: false, fail: None };
        let logger = L(User::new(1, false));
        let gw = G { row: serde_json::json!({"id":1}), mode: "ok" };
        let mut i = CropMastersTaskTemplateUpdateInteractor::new(&mut o, &gw, &logger);
        i.call(MastersCropTaskTemplateUpdateInput { user_id: 1, crop_id: 1, template_id: 2, attributes: serde_json::json!({}) }).unwrap();
        assert!(o.ok);
    }
    // Ruby: test "should return validation_failed when gateway returns ok false"
    #[test] fn validation_failed() {
        let mut o = O { ok: false, fail: None };
        let logger = L(User::new(1, false));
        let gw = G { row: serde_json::json!({}), mode: "val" };
        let mut i = CropMastersTaskTemplateUpdateInteractor::new(&mut o, &gw, &logger);
        i.call(MastersCropTaskTemplateUpdateInput { user_id: 1, crop_id: 1, template_id: 2, attributes: serde_json::json!({}) }).unwrap();
        assert_eq!(o.fail, Some(MastersCropTaskTemplateMastersFailureReason::ValidationFailed));
    }
    // Ruby: test "should return association_not_found when gateway raises RecordNotFound"
    #[test] fn association_not_found() {
        let mut o = O { ok: false, fail: None };
        let logger = L(User::new(1, false));
        let gw = G { row: serde_json::json!({}), mode: "nf" };
        let mut i = CropMastersTaskTemplateUpdateInteractor::new(&mut o, &gw, &logger);
        i.call(MastersCropTaskTemplateUpdateInput { user_id: 1, crop_id: 1, template_id: 2, attributes: serde_json::json!({}) }).unwrap();
        assert_eq!(o.fail, Some(MastersCropTaskTemplateMastersFailureReason::AssociationNotFound));
    }
