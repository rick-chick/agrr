//! Ruby: `Domain::PublicPlan::Gateways::PublicPlanGateway`

use crate::public_plan::catalog::FarmSizeRecord;
use crate::public_plan::dtos::{PublicPlanCrop, PublicPlanFarm};

/// Ruby: `Domain::PublicPlan::Gateways::PublicPlanGateway`
pub trait PublicPlanGateway: Send + Sync {
    fn find_by_farm_id(&self, farm_id: i64) -> Option<PublicPlanFarm>;

    fn find_by_farm_size_id(&self, farm_size_id: &str) -> Option<FarmSizeRecord>;

    fn list_by_ids(&self, crop_ids: &[i64], region: &str) -> Vec<PublicPlanCrop>;
}
