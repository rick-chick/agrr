// Tests for `interactors/add_crop_backfill_user_crop_stages_interactor.rs`

use crate::crop::entities::{
    CropStageEntity, TemperatureRequirementEntity, ThermalRequirementEntity,
};
use rust_decimal::Decimal;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

struct Noop;
impl LoggerPort for Noop {
    fn info(&self, _: &str) {}
    fn warn(&self, _: &str) {}
    fn error(&self, _: &str) {}
    fn debug(&self, _: &str) {}
}

fn crop(id: i64, is_ref: bool) -> CropEntity {
    CropEntity {
        id,
        user_id: if is_ref { None } else { Some(2) },
        name: "C".into(),
        variety: None,
        is_reference: is_ref,
        area_per_unit: None,
        revenue_per_area: None,
        region: None,
        groups: vec![],
        created_at: None,
        updated_at: None,
    }
}

struct SourceLookup {
    source: Option<i64>,
}
impl CropSourceCropLookupGateway for SourceLookup {
    fn find_source_crop_id(
        &self,
        _: i64,
    ) -> Result<Option<i64>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.source)
    }
}

struct CopyGw {
    copy_called: Arc<AtomicBool>,
}

impl CopyGw {
    fn new(copy_called: Arc<AtomicBool>) -> Self {
        Self { copy_called }
    }
}

impl CropGateway for CopyGw {
    fn find_by_id(&self, id: i64) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        Ok(crop(id, id == 10))
    }
    fn list_by_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
        if crop_id == 10 {
            let mut temp = TemperatureRequirementEntity::new(1, 1).unwrap();
            temp.base_temperature = Some(Decimal::from(10));
            let thermal = ThermalRequirementEntity::new(1, 1, Decimal::from(100)).unwrap();
            let mut stage = CropStageEntity::new(1, 10, "S1", 1).unwrap();
            stage.temperature_requirement = Some(temp);
            stage.thermal_requirement = Some(thermal);
            Ok(vec![stage])
        } else {
            Ok(vec![CropStageEntity::new(2, 53, "S1", 1).unwrap()])
        }
    }
    fn create_temperature_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::TemperatureRequirementUpdateInput,
    ) -> Result<
        crate::crop::entities::TemperatureRequirementEntity,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        self.copy_called.store(true, Ordering::SeqCst);
        Ok(TemperatureRequirementEntity::new(9, 2).unwrap())
    }
    fn create_thermal_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::ThermalRequirementUpdateInput,
    ) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
        Ok(ThermalRequirementEntity::new(9, 2, Decimal::from(100)).unwrap())
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
        _: &crate::shared::user::User,
        _: crate::shared::attr::AttrMap,
    ) -> Result<CropEntity, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }
    fn update_for_user(
        &self,
        _: &crate::shared::user::User,
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
    fn list_by_is_reference(
        &self,
        _: bool,
        _: Option<&str>,
    ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
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
    fn update_thermal_requirement(
        &self,
        _: i64,
        _: crate::crop::dtos::ThermalRequirementUpdateInput,
    ) -> Result<crate::crop::entities::ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>>
    {
        unimplemented!()
    }
    fn delete_thermal_requirement(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
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

#[test]
fn skips_reference_crop() {
    let copy_called = Arc::new(AtomicBool::new(false));
    let lookup = SourceLookup { source: Some(10) };
    let gw = CopyGw::new(Arc::clone(&copy_called));
    let i = AddCropBackfillUserCropStagesInteractor::new(&gw, &lookup, &Noop);
    i.call(&crop(10, true)).unwrap();
    assert!(!copy_called.load(Ordering::SeqCst));
}

#[test]
fn copies_stages_when_user_crop_has_source_crop_id() {
    let copy_called = Arc::new(AtomicBool::new(false));
    let lookup = SourceLookup { source: Some(10) };
    let gw = CopyGw::new(Arc::clone(&copy_called));
    let i = AddCropBackfillUserCropStagesInteractor::new(&gw, &lookup, &Noop);
    i.call(&crop(53, false)).unwrap();
    assert!(copy_called.load(Ordering::SeqCst));
}
