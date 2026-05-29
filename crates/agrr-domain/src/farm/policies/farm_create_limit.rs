/// Ruby: `Domain::Farm::Policies::FarmCreateLimitPolicy`
pub struct FarmCreateLimitPolicy;

impl FarmCreateLimitPolicy {
    pub const MAX_NON_REFERENCE_FARMS_PER_USER: i32 = 4;

    pub fn limit_exceeded(existing_non_reference_count: i32) -> bool {
        existing_non_reference_count >= Self::MAX_NON_REFERENCE_FARMS_PER_USER
    }
}

#[cfg(test)]
mod policies_farm_create_limit_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/policies_farm_create_limit_test.rs"));
}
