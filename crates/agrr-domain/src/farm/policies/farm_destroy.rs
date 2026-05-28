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
mod tests {
    use super::*;
    use crate::farm::dtos::FarmDeleteUsage;

    // Ruby: test "blocked_reason is nil when no free crop plans"
    #[test]
    fn blocked_reason_nil_when_no_free_crop_plans() {
        let usage = FarmDeleteUsage::new(0);
        assert!(FarmDestroyPolicy::blocked_reason(&usage).is_none());
    }

    // Ruby: test "blocked_reason is free_crop_plans when count positive"
    #[test]
    fn blocked_reason_free_crop_plans_when_count_positive() {
        let usage = FarmDeleteUsage::new(2);
        assert!(matches!(
            FarmDestroyPolicy::blocked_reason(&usage),
            Some(FarmDestroyBlockedReason::FreeCropPlans)
        ));
    }
}
