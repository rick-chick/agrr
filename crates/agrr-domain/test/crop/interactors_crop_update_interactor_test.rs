// Tests for `interactors/crop_update_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::crop::entities::CropEntity;
    use crate::crop::gateways::CropGateway;
    use crate::crop::ports::{CropUpdateOutputPort, UpdateFailure};
    use crate::shared::attr::AttrMap;
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup { fn find(&self, _: i64) -> User { self.0 } }
    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String { format!("t:{key}") }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String { String::new() }
    }
    struct SpyOutput { success: Option<CropEntity>, failure: Option<UpdateFailure> }
    impl CropUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, e: CropEntity) { self.success = Some(e); }
        fn on_failure(&mut self, e: UpdateFailure) { self.failure = Some(e); }
    }
    fn crop(user_id: i64) -> CropEntity {
        CropEntity { id: 5, user_id: Some(user_id), name: "n".into(), variety: None, is_reference: false, area_per_unit: None, revenue_per_area: None, region: None, groups: vec![], created_at: None, updated_at: None }
    }
    struct UpdateGw { current: CropEntity, updated: CropEntity, deny_edit: bool }
    impl CropGateway for UpdateGw {

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(&self, _: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> { Ok(self.current.clone()) }
        fn update_for_user(&self, _: &User, _: i64, _: AttrMap) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
            if self.deny_edit { panic!("update should not run") }
            Ok(self.updated.clone())
        }

        fn list_index_for_filter(&self, _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_show_detail(&self, _: i64) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_crop_record_with_stages(&self, _: i64) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn count_user_owned_non_reference_crops(&self, _: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create_for_user(&self, _: &crate::shared::user::User, _: crate::shared::attr::AttrMap) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn find_delete_usage(&self, _: i64) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn soft_delete_with_undo(&self, _: &crate::shared::user::User, _: i64, _: i64, _: &str) -> Result<crate::crop::gateways::SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }

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

    }

    // Ruby: test "calls on_success when gateway returns entity"
    #[test]
    fn calls_on_success_when_gateway_returns_entity() {
        let updated = crop(10);
        let gw = UpdateGw { current: crop(10), updated: updated.clone(), deny_edit: false };
        let mut out = SpyOutput { success: None, failure: None };
        let user_lookup = StubLookup(User::new(10, false));
        let mut i = CropUpdateInteractor::new(&mut out, 10, &gw, &StubTranslator, &user_lookup);
        let mut input = CropUpdateInput::new(5);
        input.name = Some("更新された名前".into());
        i.call(input).unwrap();
        assert_eq!(out.success, Some(updated));
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_with_policy_when_permission_denied() {
        let gw = UpdateGw { current: crop(99), updated: crop(10), deny_edit: true };
        let mut out = SpyOutput { success: None, failure: None };
        let user_lookup = StubLookup(User::new(10, false));
        let mut i = CropUpdateInteractor::new(&mut out, 10, &gw, &StubTranslator, &user_lookup);
        i.call(CropUpdateInput::new(5)).unwrap();
        assert!(matches!(out.failure, Some(UpdateFailure::Policy(_))));
    }

    // Ruby: test "calls on_failure with error dto when non-admin toggles is_reference"
    #[test]
    fn calls_on_failure_when_non_admin_toggles_is_reference() {
        let gw = UpdateGw { current: crop(10), updated: crop(10), deny_edit: false };
        let mut out = SpyOutput { success: None, failure: None };
        let user_lookup = StubLookup(User::new(10, false));
        let mut i = CropUpdateInteractor::new(&mut out, 10, &gw, &StubTranslator, &user_lookup);
        let mut input = CropUpdateInput::new(5);
        input.is_reference = Some(true);
        i.call(input).unwrap();
        assert!(matches!(out.failure, Some(UpdateFailure::ReferenceFlagChangeDenied(_))));
    }
