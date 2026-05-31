//! Ruby: `Domain::CultivationPlan::Interactors::EntrySchedule::StageRoleResolver`

use super::crop_stage_snapshot::CropStageSnapshot;

fn transplant_name_match(name: &str) -> bool {
    name.contains("定植") || name.contains("植え付")
}

pub struct StageRoleResolver;

impl StageRoleResolver {
    pub fn sowing_stage(stages: &[CropStageSnapshot]) -> Option<CropStageSnapshot> {
        let mut ordered: Vec<_> = stages.to_vec();
        ordered.sort_by_key(|s| s.order);
        ordered.into_iter().next()
    }

    pub fn transplant_stage(stages: &[CropStageSnapshot]) -> Option<CropStageSnapshot> {
        let mut ordered: Vec<_> = stages.to_vec();
        ordered.sort_by_key(|s| s.order);
        if ordered.is_empty() {
            return None;
        }
        if let Some(by_name) = ordered.iter().find(|s| transplant_name_match(&s.name)) {
            return Some(by_name.clone());
        }
        ordered.get(1).cloned()
    }
}

#[cfg(test)]
mod interactors_entry_schedule_stage_role_resolver_test_inline {
    
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_entry_schedule_stage_role_resolver_test.rs"));
}
