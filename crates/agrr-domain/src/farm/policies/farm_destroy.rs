use crate::farm::dtos::FarmDeleteUsage;

/// Ruby: `Domain::Farm::Policies::FarmDestroyPolicy`
pub enum FarmDestroyBlockedReason {
    FreeCropPlans,
}

pub struct FarmDestroyPolicy;

impl FarmDestroyPolicy {
    pub fn blocked_reason(usage: &FarmDeleteUsage) -> Option<FarmDestroyBlockedReason> {
        if usage.free_crop_plans_count > 0 {
            Some(FarmDestroyBlockedReason::FreeCropPlans)
        } else {
            None
        }
    }
}

#[cfg(test)]
mod policies_farm_destroy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/policies_farm_destroy_test.rs"));
}
