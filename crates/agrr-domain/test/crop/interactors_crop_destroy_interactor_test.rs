// Tests for `interactors/crop_destroy_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::crop::dtos::CropDeleteUsage;
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
        success: Option<CropDestroyOutput>,
        failure: Option<DestroyFailure>,
    }

    impl CropDestroyOutputPort for SpyOutput {
        fn on_success(&mut self, output: CropDestroyOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    fn crop(user_id: i64) -> CropEntity {
        CropEntity {
            id: 22,
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

    struct DestroyGw {
        entity: CropEntity,
        usage: CropDeleteUsage,
        undo: serde_json::Value,
    }

    impl CropGateway for DestroyGw {

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
            Ok(self.entity.clone())
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.usage.clone())
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
            Ok(SoftDeleteWithUndoOutcome::Success {
                undo: self.undo.clone(),
            })
        }

        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
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

    // Ruby: test "calls on_success when gateway returns success"
    #[test]
    fn calls_on_success_when_gateway_returns_success() {
        let undo = serde_json::json!({"id": 1});
        let gw = DestroyGw {
            entity: crop(10),
            usage: CropDeleteUsage::new(0, 0, 0),
            undo: undo.clone(),
        };
        let mut out = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup_1 = StubLookup(User::new(10, false));
        let mut i = CropDestroyInteractor::new(
            &mut out,
            10,
            &gw,
            &StubTranslator,
            &user_lookup_1,
        );
        i.call(22).unwrap();
        assert_eq!(out.success, Some(CropDestroyOutput::new(undo)));
    }

    // Ruby: test "calls on_failure with policy exception when permission is denied"
    #[test]
    fn calls_on_failure_with_policy_when_permission_denied() {
        let gw = DestroyGw {
            entity: crop(99),
            usage: CropDeleteUsage::new(0, 0, 0),
            undo: serde_json::json!({}),
        };
        let mut out = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup_1 = StubLookup(User::new(10, false));
        let user_lookup = StubLookup(User::new(10, false));
        let mut i = CropDestroyInteractor::new(
            &mut out,
            10,
            &gw,
            &StubTranslator,
            &user_lookup,
        );
        i.call(22).unwrap();
        assert!(matches!(
            out.failure,
            Some(DestroyFailure::Policy(PolicyPermissionDenied))
        ));
    }

    // Ruby: test "calls on_failure when cultivation plan crops block delete"
    #[test]
    fn calls_on_failure_when_cultivation_plan_crops_block_delete() {
        let gw = DestroyGw {
            entity: crop(10),
            usage: CropDeleteUsage::new(1, 0, 0),
            undo: serde_json::json!({}),
        };
        let mut out = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup_1 = StubLookup(User::new(10, false));
        let user_lookup = StubLookup(User::new(10, false));
        let mut i = CropDestroyInteractor::new(
            &mut out,
            10,
            &gw,
            &StubTranslator,
            &user_lookup,
        );
        i.call(22).unwrap();
        match out.failure {
            Some(DestroyFailure::Error(e)) => {
                assert_eq!(e.message, "crops.flash.cannot_delete_in_use.plan");
            }
            other => panic!("expected Error, got {other:?}"),
        }
    }
