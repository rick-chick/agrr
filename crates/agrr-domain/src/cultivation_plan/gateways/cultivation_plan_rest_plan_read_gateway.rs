//! Ruby: `Domain::CultivationPlan::Gateways::CultivationPlanRestPlanReadGateway`

use crate::cultivation_plan::dtos::rest_plan_snapshots::{
    CultivationPlanRestPlanCropRowSnapshot, CultivationPlanRestPlanCultivationRowSnapshot,
    CultivationPlanRestPlanFieldRowSnapshot, CultivationPlanRestPlanHeaderSnapshot,
};

pub trait CultivationPlanRestPlanReadGateway: Send + Sync {
    fn find_plan_header_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<CultivationPlanRestPlanHeaderSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn list_rest_plan_field_row_snapshots_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<CultivationPlanRestPlanFieldRowSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_rest_plan_crop_row_snapshots_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<CultivationPlanRestPlanCropRowSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_rest_plan_cultivation_row_snapshots_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<CultivationPlanRestPlanCultivationRowSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_palette_crop_ids_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>>;
}
