use crate::farm::dtos::{FarmDeleteUsage, FarmDetailOutput};
use crate::farm::entities::FarmEntity;
use crate::shared::attr::AttrMap;
use crate::shared::dtos::Error;
use crate::shared::user::User;

/// Ruby: `Domain::Farm::Gateways::FarmGateway`
pub trait FarmGateway: Send + Sync {
    fn list_user_owned_farms(
        &self,
        user_id: i64,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_user_and_reference_farms(
        &self,
        user_id: i64,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_reference_farms(
        &self,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_id(
        &self,
        farm_id: i64,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update_weather_progress(
        &self,
        farm_id: i64,
        attrs: AttrMap,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn list_reference_farms_for_region(
        &self,
        region: &str,
    ) -> Result<Vec<FarmEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn count_user_owned_non_reference_farms(
        &self,
        user_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>>;

    fn create_for_user(
        &self,
        user: &User,
        attrs: AttrMap,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update_for_user(
        &self,
        user: &User,
        farm_id: i64,
        attrs: AttrMap,
    ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn farm_detail_with_fields(
        &self,
        farm_id: i64,
    ) -> Result<FarmDetailOutput, Box<dyn std::error::Error + Send + Sync>>;

    fn find_delete_usage(
        &self,
        farm_id: i64,
    ) -> Result<FarmDeleteUsage, Box<dyn std::error::Error + Send + Sync>>;

    fn soft_delete_with_undo(
        &self,
        user: &User,
        farm_id: i64,
        auto_hide_after: i64,
        toast_message: &str,
    ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>>;
}

#[derive(Debug, Clone)]
pub enum SoftDeleteWithUndoOutcome {
    Success {
        undo: serde_json::Value,
        farm_name: String,
    },
    Failure(Error),
}
