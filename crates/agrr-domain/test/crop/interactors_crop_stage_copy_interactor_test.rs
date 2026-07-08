// Tests for `interactors/crop_stage_copy_interactor.rs` (Ruby parity under test/domain/crop/).

    use crate::crop::entities::{
        TemperatureRequirementEntity, ThermalRequirementEntity,
    };
    use std::sync::atomic::{AtomicBool, Ordering};

    static CREATE_TEMP_CALLED: AtomicBool = AtomicBool::new(false);

    struct CopyGw;
    impl CropGateway for CopyGw {

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
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(crate::crop::entities::CropEntity::new(1, "c", None, false).unwrap())
        }

    fn list_by_crop_id(
            &self,
            crop_id: i64,
        ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
            if crop_id == 1 {
                let mut temp =
                    TemperatureRequirementEntity::new(1, 10).unwrap();
                temp.base_temperature = Some(Decimal::from(10));
                temp.optimal_min = Some(Decimal::from(15));
                temp.optimal_max = Some(Decimal::from(25));
                temp.low_stress_threshold = Some(Decimal::from(5));
                temp.high_stress_threshold = Some(Decimal::from(30));
                temp.frost_threshold = Some(Decimal::from(0));
                temp.max_temperature = Some(Decimal::from(35));
                let mut stage = CropStageEntity::new(10, 1, "Vegetative", 1).unwrap();
                stage.temperature_requirement = Some(temp);
                Ok(vec![stage])
            } else {
                Ok(vec![])
            }
        }
        fn create_crop_stage(
            &self,
            input: CropStageCreateInput,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(CropStageEntity::new(20, input.crop_id, "Vegetative", 1).unwrap())
        }
        fn create_temperature_requirement(
            &self,
            _: i64,
            _: TemperatureRequirementUpdateInput,
        ) -> Result<TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
            CREATE_TEMP_CALLED.store(true, Ordering::SeqCst);
            Ok(TemperatureRequirementEntity::new(2, 20).unwrap())
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<
            Vec<crate::crop::entities::CropEntity>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
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
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
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
            _: &crate::shared::user::User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
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
            _: &crate::shared::user::User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::crop::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_crop_stage(
            &self,
            _: i64,
            _: crate::crop::dtos::CropStageUpdateInput,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_thermal_requirement(
            &self,
            _: i64,
            _: ThermalRequirementUpdateInput,
        ) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_thermal_requirement(
            &self,
            _: i64,
            _: ThermalRequirementUpdateInput,
        ) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete_thermal_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_temperature_requirement(
            &self,
            _: i64,
            _: TemperatureRequirementUpdateInput,
        ) -> Result<TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
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
            _: SunshineRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::SunshineRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_sunshine_requirement(
            &self,
            _: i64,
            _: SunshineRequirementUpdateInput,
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
            _: NutrientRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::NutrientRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_nutrient_requirement(
            &self,
            _: i64,
            _: NutrientRequirementUpdateInput,
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
    }

    // Ruby: test "creates missing stage and requirements on target crop"
    #[test]
    fn creates_missing_stage_and_requirements_on_target_crop() {
        CREATE_TEMP_CALLED.store(false, Ordering::SeqCst);
        let i = CropStageCopyInteractor::new(&CopyGw);
        i.call(CropStageCopyInput {
            reference_crop_id: 1,
            new_crop_id: 2,
        })
        .unwrap();
        assert!(CREATE_TEMP_CALLED.load(Ordering::SeqCst));
    }
