//! Ruby: `Domain::CultivationPlan::Gateways::PlanSaveUserPestGateway`

use crate::cultivation_plan::dtos::PlanSaveUserPestSnapshot;
use crate::shared::attr::AttrMap;

pub trait PlanSaveUserPestGateway: Send + Sync {
    fn find_by_user_id_and_source_pest_id(
        &self,
        user_id: i64,
        source_pest_id: i64,
    ) -> Result<Option<PlanSaveUserPestSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
    ) -> Result<PlanSaveUserPestSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn create_temperature_profile(&self, pest_id: i64, attributes: AttrMap);

    fn create_thermal_requirement(&self, pest_id: i64, attributes: AttrMap);

    fn create_control_method(&self, pest_id: i64, attributes: AttrMap);

    fn link_crop_pest(&self, crop_id: i64, pest_id: i64);
}
