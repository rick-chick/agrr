use super::{
    FieldCultivationSyncCultivationPlanSummary, FieldCultivationSyncDesiredRow,
};

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationSyncApply {
    pub field_cultivations_to_update: Vec<FieldCultivationSyncDesiredRow>,
    pub field_cultivations_to_create: Vec<FieldCultivationSyncDesiredRow>,
    pub field_cultivation_ids_to_delete: Vec<i64>,
    pub cultivation_plan_crop_ids_to_delete: Vec<i64>,
    pub cultivation_plan_summary: FieldCultivationSyncCultivationPlanSummary,
}
