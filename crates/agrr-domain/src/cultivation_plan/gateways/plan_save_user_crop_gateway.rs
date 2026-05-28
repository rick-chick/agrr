//! Ruby: `Domain::CultivationPlan::Gateways::PlanSaveUserCropGateway`

use crate::cultivation_plan::dtos::PlanSaveUserCropSnapshot;
use crate::shared::attr::AttrMap;

pub trait PlanSaveUserCropGateway: Send + Sync {
    fn find_by_user_id_and_source_crop_id(
        &self,
        user_id: i64,
        source_crop_id: i64,
    ) -> Result<Option<PlanSaveUserCropSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserCropSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
