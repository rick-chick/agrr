//! Ruby: plan copy persistence port.

use crate::cultivation_plan::dtos::{
    PlanCopyCreateAttrs, PlanCopyCropSnapshot, PlanCopyFieldCultivationSnapshot,
    PlanCopyFieldSnapshot, PlanCopySourcePlan,
};
use crate::cultivation_plan::entities::CultivationPlanEntity;

pub trait PlanCopyGateway: Send + Sync {
    fn find_plan(
        &self,
        source_plan_id: i64,
    ) -> Result<PlanCopySourcePlan, Box<dyn std::error::Error + Send + Sync>>;

    fn create_plan(
        &self,
        attrs: &PlanCopyCreateAttrs,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn list_fields(
        &self,
        source_plan_id: i64,
    ) -> Result<Vec<PlanCopyFieldSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn create_field(
        &self,
        plan_id: i64,
        name: &str,
        area: f64,
        daily_fixed_cost: f64,
        description: Option<&str>,
    ) -> Result<PlanCopyFieldSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn list_crops(
        &self,
        source_plan_id: i64,
    ) -> Result<Vec<PlanCopyCropSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn create_crop(
        &self,
        plan_id: i64,
        crop_id: i64,
        name: &str,
        variety: Option<&str>,
        area_per_unit: f64,
        revenue_per_area: f64,
    ) -> Result<PlanCopyCropSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn list_field_cultivations(
        &self,
        source_plan_id: i64,
    ) -> Result<Vec<PlanCopyFieldCultivationSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn create_field_cultivation(
        &self,
        plan_id: i64,
        cultivation_plan_field_id: i64,
        cultivation_plan_crop_id: i64,
        area: f64,
        status: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
