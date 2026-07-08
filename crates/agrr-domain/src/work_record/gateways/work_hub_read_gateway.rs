//! Read gateway for work hub farm rows.

use crate::work_record::dtos::WorkHubFarmRow;

pub trait WorkHubReadGateway: Send + Sync {
    fn list_farm_rows_for_user(
        &self,
        user_id: i64,
    ) -> Result<Vec<WorkHubFarmRow>, Box<dyn std::error::Error + Send + Sync>>;
}
