use crate::field_cultivation::dtos::FieldCultivationApiUpdateOutput;
use crate::field_cultivation::dtos::{
    FieldCultivationApiSummary, FieldCultivationPlanAccessSnapshot,
};

/// Ruby: `Domain::FieldCultivation::Gateways::FieldCultivationGateway`
pub trait FieldCultivationGateway: Send + Sync {
    fn find_plan_access_snapshot_by_field_cultivation_id(
        &self,
        field_cultivation_id: i64,
    ) -> Result<FieldCultivationPlanAccessSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn find_api_summary_by_field_cultivation_id(
        &self,
        field_cultivation_id: i64,
    ) -> Result<FieldCultivationApiSummary, Box<dyn std::error::Error + Send + Sync>>;

    fn update_field_cultivation_schedule(
        &self,
        field_cultivation_id: i64,
        start_date: &str,
        completion_date: &str,
        cultivation_days: Option<i32>,
    ) -> Result<FieldCultivationApiUpdateOutput, Box<dyn std::error::Error + Send + Sync>>;
}
