//! Ruby: `Domain::Crop::Policies::CropCreateLimitPolicy`

pub const MAX_NON_REFERENCE_CROPS_PER_USER: i32 = 20;

pub fn limit_exceeded(existing_non_reference_count: i32, is_reference: bool) -> bool {
    if is_reference {
        return false;
    }
    existing_non_reference_count >= MAX_NON_REFERENCE_CROPS_PER_USER
}

#[cfg(test)]
mod policies_crop_create_limit_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/policies_crop_create_limit_policy_test.rs"));
}
