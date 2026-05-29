//! Ruby: `CropRowsAvailablePublicActiveRecordGateway`

use crate::crop::CropSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::crop::gateways::CropGateway;
use agrr_domain::cultivation_plan::dtos::CropRowsAvailableRow;
use agrr_domain::cultivation_plan::gateways::CropRowsAvailableGateway;

pub struct CropRowsAvailablePublicSqliteGateway {
    crop_gateway: CropSqliteGateway,
}

impl CropRowsAvailablePublicSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self {
            crop_gateway: CropSqliteGateway::new(pool),
        }
    }
}

impl CropRowsAvailableGateway for CropRowsAvailablePublicSqliteGateway {
    fn list_by_farm_region(
        &self,
        _auth: &serde_json::Value,
        farm_region: Option<&str>,
    ) -> Result<Vec<CropRowsAvailableRow>, Box<dyn std::error::Error + Send + Sync>> {
        let region = farm_region.unwrap_or("");
        let mut crops = self
            .crop_gateway
            .list_by_is_reference(true, Some(region))?;
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
