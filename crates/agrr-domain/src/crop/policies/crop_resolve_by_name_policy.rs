//! Ruby: `Domain::Crop::Policies::CropResolveByNamePolicy`

use crate::crop::entities::CropEntity;
use crate::shared::policies::crop_policy;
use crate::shared::user::User;

pub fn select_id_for_pest_ai_name_fallback(user: &User, candidates: &[CropEntity]) -> Option<i64> {
    if candidates.is_empty() {
        return None;
    }
    if let Some(reference) = candidates.iter().find(|c| c.is_reference) {
        return Some(reference.id);
    }
    candidates
        .iter()
        .find(|c| crop_policy::edit_allowed(user, c.is_reference, c.user_id))
        .map(|c| c.id)
}

#[cfg(test)]
mod policies_crop_resolve_by_name_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/policies_crop_resolve_by_name_policy_test.rs"));
}
