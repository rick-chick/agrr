//! Ruby: `Domain::CultivationPlan::Gateways::PlanSaveUserFertilizeGateway`

use crate::cultivation_plan::dtos::PlanSaveUserFertilizeSnapshot;
use crate::shared::attr::AttrMap;

pub trait PlanSaveUserFertilizeGateway: Send + Sync {
    fn find_by_user_id_and_source_fertilize_id(
        &self,
        user_id: i64,
        source_fertilize_id: i64,
    ) -> Result<Option<PlanSaveUserFertilizeSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserFertilizeSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
