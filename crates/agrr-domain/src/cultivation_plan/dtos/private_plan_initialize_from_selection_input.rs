//! Ruby: `Domain::CultivationPlan::Dtos::PrivatePlanInitializeFromSelectionInput`

use crate::shared::user::User;

#[derive(Debug, Clone, PartialEq)]
pub struct PrivatePlanInitializeFromSelectionInput {
    pub farm_id: i64,
    pub crop_ids: Vec<i64>,
    pub user: User,
    pub plan_name: Option<String>,
}

impl PrivatePlanInitializeFromSelectionInput {
    pub fn normalized_crop_ids(&self) -> Vec<i64> {
        let mut ids: Vec<i64> = self
            .crop_ids
            .iter()
            .copied()
            .filter(|id| *id != 0)
            .collect();
        ids.sort_unstable();
        ids.dedup();
        ids
    }
}
