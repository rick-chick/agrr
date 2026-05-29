// Tests for `policies/farm_create_limit.rs` (Ruby parity under test/domain/farm/).

use crate::farm::policies::farm_create_limit::FarmCreateLimitPolicy;

    // Ruby: test "limit_exceeded? is false below max"
    #[test]
    fn limit_exceeded_false_below_max() {
        assert!(!FarmCreateLimitPolicy::limit_exceeded(3));
    }

    // Ruby: test "limit_exceeded? is false at max minus one"
    #[test]
    fn limit_exceeded_false_at_max_minus_one() {
        assert!(!FarmCreateLimitPolicy::limit_exceeded(
            FarmCreateLimitPolicy::MAX_NON_REFERENCE_FARMS_PER_USER - 1
        ));
    }

    // Ruby: test "limit_exceeded? is true at max"
    #[test]
    fn limit_exceeded_true_at_max() {
        assert!(FarmCreateLimitPolicy::limit_exceeded(
            FarmCreateLimitPolicy::MAX_NON_REFERENCE_FARMS_PER_USER
        ));
    }

    // Ruby: test "limit_exceeded? is true above max"
    #[test]
    fn limit_exceeded_true_above_max() {
        assert!(FarmCreateLimitPolicy::limit_exceeded(
            FarmCreateLimitPolicy::MAX_NON_REFERENCE_FARMS_PER_USER + 1
        ));
    }
