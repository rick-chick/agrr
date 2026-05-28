use crate::field_cultivation::dtos::{
    FieldCultivationApiSummary, FieldCultivationApiUpdateOutput,
};
use crate::field_cultivation::gateways::FieldCultivationPlanAccessGateway;

/// Ruby: `Domain::FieldCultivation::Gateways::FieldCultivationGateway`
pub trait FieldCultivationGateway: FieldCultivationPlanAccessGateway {
    fn find_api_summary(
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
