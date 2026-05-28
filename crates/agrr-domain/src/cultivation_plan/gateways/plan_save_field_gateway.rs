//! Ruby: `Domain::CultivationPlan::Gateways::PlanSaveFieldGateway`

use crate::cultivation_plan::dtos::PlanSaveFieldSnapshot;
use crate::shared::attr::AttrMap;

pub trait PlanSaveFieldGateway: Send + Sync {
    fn list_by_farm_id(
        &self,
        farm_id: i64,
        user_id: i64,
    ) -> Result<Vec<PlanSaveFieldSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        farm_id: i64,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveFieldSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
