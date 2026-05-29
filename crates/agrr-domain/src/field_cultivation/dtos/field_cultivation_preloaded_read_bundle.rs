use super::{
    FieldCultivationApiSummary, FieldCultivationClimateSourceSnapshot,
    FieldCultivationPlanAccessSnapshot,
};

/// Ruby: `Domain::FieldCultivation::Dtos::FieldCultivationPreloadedReadBundle`
#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationPreloadedReadBundle {
    pub plan_access_snapshot: FieldCultivationPlanAccessSnapshot,
    pub climate_source_snapshot: FieldCultivationClimateSourceSnapshot,
    pub api_summary: FieldCultivationApiSummary,
}
