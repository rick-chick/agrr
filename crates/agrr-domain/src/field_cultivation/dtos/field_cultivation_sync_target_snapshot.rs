use super::{
    FieldCultivationSyncCultivationPlanSummary, FieldCultivationSyncDesiredRow,
};

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationSyncTargetSnapshot {
    pub field_cultivation_rows: Vec<FieldCultivationSyncDesiredRow>,
    pub cultivation_plan_summary: FieldCultivationSyncCultivationPlanSummary,
    pub referenced_crop_ids: Vec<String>,
}
