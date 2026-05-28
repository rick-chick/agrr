//! Ruby: `Domain::CultivationPlan::Gateways::PlanSaveUserPesticideGateway`

use crate::cultivation_plan::dtos::PlanSaveUserPesticideSnapshot;
use crate::shared::attr::AttrMap;

pub trait PlanSaveUserPesticideGateway: Send + Sync {
    fn find_by_user_id_and_source_pesticide_id(
        &self,
        user_id: i64,
        source_pesticide_id: i64,
    ) -> Result<Option<PlanSaveUserPesticideSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        user_id: i64,
        attributes: AttrMap,
        usage_constraint_attributes: Option<AttrMap>,
        application_detail_attributes: Option<AttrMap>,
    ) -> Result<PlanSaveUserPesticideSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
