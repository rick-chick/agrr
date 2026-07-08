use crate::crop::agrr_requirement::build_crop_agrr_requirement;
use crate::pool::SqlitePool;
use agrr_domain::crop::gateways::CropAgrrRequirementGateway;
use serde_json::Value;

pub struct CropAgrrRequirementSqliteGateway {
    pool: SqlitePool,
}

impl CropAgrrRequirementSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl CropAgrrRequirementGateway for CropAgrrRequirementSqliteGateway {
    fn build_for_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
        build_crop_agrr_requirement(&self.pool, crop_id)
    }
}
