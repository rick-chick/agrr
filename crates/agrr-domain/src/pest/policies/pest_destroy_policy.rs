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
mod tests {
    use super::*;
    use crate::pest::dtos::PestDeleteUsage;

    // Ruby: test "blocked_reason is nil when no pesticides"
    #[test]
    fn blocked_reason_nil_when_no_pesticides() {
        let usage = PestDeleteUsage::new(0);
        assert!(blocked_reason(&usage).is_none());
    }

    // Ruby: test "blocked_reason is pesticides_in_use when count positive"
    #[test]
    fn blocked_reason_pesticides_in_use_when_count_positive() {
        let usage = PestDeleteUsage::new(1);
        assert_eq!(
            blocked_reason(&usage),
            Some(PestDestroyBlockedReason::PesticidesInUse)
        );
    }
}
