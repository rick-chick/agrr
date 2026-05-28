//! Ruby: `Domain::CultivationPlan::Gateways::CropTaskScheduleBlueprintGateway`

use crate::cultivation_plan::dtos::{
    crop_task_schedule_blueprint::{CropTaskScheduleBlueprintCreateAttrs, CropTaskScheduleBlueprintRow},
};

pub trait CropTaskScheduleBlueprintGateway: Send + Sync {
    fn list_by_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Vec<CropTaskScheduleBlueprintRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn delete_by_crop_id(&self, crop_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn bulk_create(
        &self,
        records: &[CropTaskScheduleBlueprintCreateAttrs],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}

