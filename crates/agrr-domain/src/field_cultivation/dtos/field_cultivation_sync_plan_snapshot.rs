use std::collections::{HashMap, HashSet};

use super::{
    FieldCultivationSyncExistingFieldCultivationEntry, FieldCultivationSyncPlanCropEntry,
};

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationSyncPlanSnapshot {
    pub plan_id: i64,
    pub plan_fields_by_id: HashMap<i64, i64>,
    pub plan_crop_rows: Vec<FieldCultivationSyncPlanCropEntry>,
    pub existing_field_cultivations_by_id: HashMap<i64, FieldCultivationSyncExistingFieldCultivationEntry>,
}

impl FieldCultivationSyncPlanSnapshot {
    pub fn existing_field_cultivation_ids(&self) -> HashSet<i64> {
        self.existing_field_cultivations_by_id.keys().copied().collect()
    }
}
