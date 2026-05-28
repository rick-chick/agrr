//! Ruby: `Domain::Crop::Policies::CropCreateLimitPolicy`

pub const MAX_NON_REFERENCE_CROPS_PER_USER: i32 = 20;

pub fn limit_exceeded(existing_non_reference_count: i32, is_reference: bool) -> bool {
    if is_reference {
        return false;
    }
    existing_non_reference_count >= MAX_NON_REFERENCE_CROPS_PER_USER
}

#[cfg(test)]
mod tests {
    use super::*;

    // Ruby: test "limit_exceeded? is false below max"
    #[test]
    fn limit_exceeded_is_false_below_max() {
        assert!(!limit_exceeded(19, false));
    }

    // Ruby: test "limit_exceeded? is true at max"
    #[test]
    fn limit_exceeded_is_true_at_max() {
        assert!(limit_exceeded(20, false));
    }

    // Ruby: test "limit_exceeded? is true above max"
    #[test]
    fn limit_exceeded_is_true_above_max() {
        assert!(limit_exceeded(21, false));
    }

    // Ruby: test "limit_exceeded? is false for reference crop"
    #[test]
    fn limit_exceeded_is_false_for_reference_crop() {
        assert!(!limit_exceeded(100, true));
    }
}
