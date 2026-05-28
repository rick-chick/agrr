//! Ruby: `Domain::CultivationPlan::Gateways::PlanSaveFarmGateway`

use crate::cultivation_plan::dtos::{PlanSaveReferenceFarmSnapshot, PlanSaveUserFarmSnapshot};
use serde_json::Value;

pub trait PlanSaveFarmGateway: Send + Sync {
    fn find_reference_farm(
        &self,
        farm_id: Option<i64>,
    ) -> Result<Option<PlanSaveReferenceFarmSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_user_farm_by_source(
        &self,
        user_id: i64,
        source_farm_id: i64,
    ) -> Result<Option<PlanSaveUserFarmSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn count_non_reference_farms(
        &self,
        user_id: i64,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>>;

    fn create_user_farm_from_reference(
        &self,
        user_id: i64,
        reference_farm_id: i64,
        copy_name_suffix: &str,
    ) -> Result<PlanSaveUserFarmSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn find_owned_farm_record(
        &self,
        user_id: i64,
        farm_id: i64,
    ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_owned_private_plan_record(
        &self,
        user_id: i64,
        farm_id: i64,
    ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>>;
}
