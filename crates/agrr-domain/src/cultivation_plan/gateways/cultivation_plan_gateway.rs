//! Ruby: `Domain::CultivationPlan::Gateways::CultivationPlanGateway`

use std::collections::HashMap;

use serde_json::Value;

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::shared::user::User;

pub trait CultivationPlanGateway: Send + Sync {
    fn find_by_id(
        &self,
        plan_id: i64,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        attrs: &CultivationPlanCreateAttrs,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update(
        &self,
        plan_id: i64,
        attrs: HashMap<String, String>,
    ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn list_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn within_transaction<F, T>(&self, block: F) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>;

    fn private_owned_plan_display_name(
        &self,
        user: &User,
        plan_id: i64,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>>;

    fn delete(
        &self,
        plan_id: i64,
        user: &User,
        toast_message: &str,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;
}
