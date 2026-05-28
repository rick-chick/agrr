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
mod tests {
    use super::*;

    // Ruby: test "blocked_reason returns cultivation_plan when cultivation_plan_crops_count positive"
    #[test]
    fn blocked_by_cultivation_plan() {
        let usage = CropDeleteUsage::new(1, 0, 0);
        assert_eq!(
            blocked_reason(&usage),
            Some(CropDestroyBlockedReason::CultivationPlan)
        );
    }

    // Ruby: test "blocked_reason returns other when free crop plans or pesticides in use"
    #[test]
    fn blocked_by_other_usage() {
        let usage = CropDeleteUsage::new(0, 2, 0);
        assert_eq!(blocked_reason(&usage), Some(CropDestroyBlockedReason::Other));
        let usage2 = CropDeleteUsage::new(0, 0, 1);
        assert_eq!(blocked_reason(&usage2), Some(CropDestroyBlockedReason::Other));
    }

    // Ruby: test "blocked_reason returns nil when no usage"
    #[test]
    fn not_blocked_when_no_usage() {
        let usage = CropDeleteUsage::new(0, 0, 0);
        assert_eq!(blocked_reason(&usage), None);
    }
}
