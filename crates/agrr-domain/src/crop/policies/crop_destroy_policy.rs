//! Ruby: `Domain::Crop::Policies::CropDestroyPolicy`

use crate::crop::dtos::CropDeleteUsage;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CropDestroyBlockedReason {
    CultivationPlan,
    Other,
}

pub fn blocked_reason(usage: &CropDeleteUsage) -> Option<CropDestroyBlockedReason> {
    if usage.cultivation_plan_crops_count > 0 {
        return Some(CropDestroyBlockedReason::CultivationPlan);
    }
    if usage.free_crop_plans_count > 0 || usage.pesticides_count > 0 {
        return Some(CropDestroyBlockedReason::Other);
    }
    None
}

#[cfg(test)]
mod policies_crop_destroy_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/policies_crop_destroy_policy_test.rs"));
}
