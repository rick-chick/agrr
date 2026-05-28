//! Plan crop mutations for initialize / add_crop.

use crate::crop::dtos::AddCropCropSnapshot;
use crate::cultivation_plan::dtos::{
    CultivationPlanCropSnapshot, CultivationPlanPlanCropCreateAttrs,
};

pub trait CultivationPlanPlanCropGateway: Send + Sync {
    fn create_for_plan(
        &self,
        attrs: &CultivationPlanPlanCropCreateAttrs,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        plan_id: i64,
        crop_entity: &AddCropCropSnapshot,
    ) -> Result<CultivationPlanCropSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn delete(&self, id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
