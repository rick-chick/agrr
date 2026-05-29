// Tests for `policies/farm_reference_ownership.rs` (Ruby parity under test/domain/farm/).

use crate::farm::policies::farm_reference_ownership::FarmReferenceOwnershipPolicy;

    // Ruby: test "reference_farm_user_valid? は非参照農場なら常に true"
    #[test]
    fn reference_farm_user_valid_non_reference_always_true() {
        assert!(FarmReferenceOwnershipPolicy::reference_farm_user_valid(
            false, false
        ));
    }

    // Ruby: test "reference_farm_user_valid? は参照農場はアノニマス所有者のみ"
    #[test]
    fn reference_farm_user_valid_reference_requires_anonymous_owner() {
        assert!(FarmReferenceOwnershipPolicy::reference_farm_user_valid(
            true, true
        ));
        assert!(!FarmReferenceOwnershipPolicy::reference_farm_user_valid(
            true, false
        ));
    }
