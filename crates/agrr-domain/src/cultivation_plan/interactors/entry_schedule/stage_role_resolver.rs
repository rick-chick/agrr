//! Ruby: `Domain::CultivationPlan::Interactors::EntrySchedule::StageRoleResolver`

use super::crop_stage_snapshot::CropStageSnapshot;

pub struct StageRoleResolver;

impl StageRoleResolver {
    /// Crop master with a transplant-named stage is transplant cultivation; otherwise direct sow.
    pub fn has_transplant_stage(stages: &[CropStageSnapshot]) -> bool {
        stages.iter().any(|s| transplant_name_match(&s.name))
    }

    pub fn sowing_stage(stages: &[CropStageSnapshot]) -> Option<CropStageSnapshot> {
        let mut ordered: Vec<_> = stages.to_vec();
        ordered.sort_by_key(|s| s.order);
        ordered.into_iter().next()
    }

    pub fn entry_stage_for_direct_sow(stages: &[CropStageSnapshot]) -> Option<CropStageSnapshot> {
        Self::sowing_stage(stages)
    }

    /// Field transplant entry stage: order=2 across reference fixtures (jp/us/in).
    pub fn entry_stage_for_transplant(stages: &[CropStageSnapshot]) -> Option<CropStageSnapshot> {
        let mut ordered: Vec<_> = stages.to_vec();
        ordered.sort_by_key(|s| s.order);
        ordered.get(1).cloned()
    }
}

#[cfg(test)]
mod interactors_entry_schedule_stage_role_resolver_test_inline {
    
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_entry_schedule_stage_role_resolver_test.rs"));
}
