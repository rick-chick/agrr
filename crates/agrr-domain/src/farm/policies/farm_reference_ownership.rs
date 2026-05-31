/// Ruby: `Domain::Farm::Policies::FarmReferenceOwnershipPolicy`
pub struct FarmReferenceOwnershipPolicy;

impl FarmReferenceOwnershipPolicy {
    pub fn reference_farm_user_valid(is_reference: bool, owner_is_anonymous: bool) -> bool {
        !is_reference || owner_is_anonymous
    }
}

#[cfg(test)]
mod policies_farm_reference_ownership_test_inline {
    
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/policies_farm_reference_ownership_test.rs"));
}
