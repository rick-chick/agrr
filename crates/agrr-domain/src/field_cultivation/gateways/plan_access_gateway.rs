use crate::field_cultivation::dtos::FieldCultivationPlanAccessSnapshot;

/// Shared plan-access read for show/update/climate gateways.
pub trait FieldCultivationPlanAccessGateway: Send + Sync {
    fn find_plan_access_snapshot_by_field_cultivation_id(
        &self,
        field_cultivation_id: i64,
    ) -> Result<FieldCultivationPlanAccessSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
