//! Ruby: `Domain::CultivationPlan::Gateways::CropRowsAvailableGateway`

use crate::cultivation_plan::dtos::CropRowsAvailableRow;

pub trait CropRowsAvailableGateway: Send + Sync {
    fn list_by_farm_region(
        &self,
        auth: &serde_json::Value,
        farm_region: Option<&str>,
    ) -> Result<Vec<CropRowsAvailableRow>, Box<dyn std::error::Error + Send + Sync>>;
}
