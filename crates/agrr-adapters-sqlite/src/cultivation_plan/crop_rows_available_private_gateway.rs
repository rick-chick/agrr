//! Ruby: `CropRowsAvailablePrivateActiveRecordGateway`

use crate::crop::CropSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::crop::gateways::CropGateway;
use agrr_domain::cultivation_plan::dtos::CropRowsAvailableRow;
use agrr_domain::cultivation_plan::dtos::CultivationPlanRestAuth;
use agrr_domain::crop::policies::crop_reference_record_policy::region_matches;
use agrr_domain::cultivation_plan::gateways::CropRowsAvailableGateway;
use agrr_domain::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};

pub struct CropRowsAvailablePrivateSqliteGateway {
    crop_gateway: CropSqliteGateway,
}

impl CropRowsAvailablePrivateSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self {
            crop_gateway: CropSqliteGateway::new(pool),
        }
    }
}

impl CropRowsAvailableGateway for CropRowsAvailablePrivateSqliteGateway {
    fn list_by_farm_region(
        &self,
        auth: &serde_json::Value,
        farm_region: Option<&str>,
    ) -> Result<Vec<CropRowsAvailableRow>, Box<dyn std::error::Error + Send + Sync>> {
        let parsed: CultivationPlanRestAuth = match serde_json::from_value(auth.clone()) {
            Ok(v) => v,
            Err(_) => return Ok(vec![]),
        };
        let user_id = match parsed.user_id {
            Some(id) => id,
            None => return Ok(vec![]),
        };
        let filter = ReferenceIndexListFilter {
            mode: ReferenceIndexListMode::OwnedNonReference,
            user_id,
        };
        let mut crops = self.crop_gateway.list_index_for_filter(&filter)?;
        crops.retain(|crop| region_matches(farm_region, crop.region.as_deref()));
        crops.sort_by(|a, b| a.name.cmp(&b.name));
        Ok(crops
            .into_iter()
            .map(|c| CropRowsAvailableRow {
                id: c.id,
                name: c.name,
                variety: c.variety,
                area_per_unit: c.area_per_unit,
            })
            .collect())
    }
}

#[cfg(test)]
mod crop_rows_available_private_gateway_test {
    include!("crop_rows_available_private_gateway_test.rs");
}
