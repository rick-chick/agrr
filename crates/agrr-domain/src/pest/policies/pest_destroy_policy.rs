use crate::pest::dtos::PestDeleteUsage;

/// Ruby: `Domain::Pest::Policies::PestDestroyPolicy`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PestDestroyBlockedReason {
    PesticidesInUse,
}

pub fn blocked_reason(usage: &PestDeleteUsage) -> Option<PestDestroyBlockedReason> {
    if usage.pesticides_count > 0 {
        Some(PestDestroyBlockedReason::PesticidesInUse)
    } else {
        None
    }
}

#[cfg(test)]
mod policies_pest_destroy_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/policies_pest_destroy_policy_test.rs"));
}
