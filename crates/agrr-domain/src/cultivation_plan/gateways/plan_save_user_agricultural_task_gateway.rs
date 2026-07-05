//! Ruby: `Domain::CultivationPlan::Gateways::PlanSaveUserAgriculturalTaskGateway`

use crate::cultivation_plan::dtos::PlanSaveUserAgriculturalTaskSnapshot;
use crate::shared::attr::AttrMap;

pub trait PlanSaveUserAgriculturalTaskGateway: Send + Sync {
    fn find_by_user_id_and_source_agricultural_task_id(
        &self,
        user_id: i64,
        source_agricultural_task_id: i64,
    ) -> Result<Option<PlanSaveUserAgriculturalTaskSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserAgriculturalTaskSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
