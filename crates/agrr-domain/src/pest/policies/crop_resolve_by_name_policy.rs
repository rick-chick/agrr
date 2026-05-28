use crate::pest::gateways::CropRecord;
use crate::shared::policies::crop_policy;
use crate::shared::user::User;

/// Ruby: `Domain::Crop::Policies::CropResolveByNamePolicy`
pub fn select_id_for_pest_ai_name_fallback(user: &User, candidates: &[CropRecord]) -> Option<i64> {
    if candidates.is_empty() {
        return None;
    }

    if let Some(reference) = candidates.iter().find(|crop| crop.is_reference) {
        return Some(reference.id);
    }

    candidates
        .iter()
        .find(|crop| crop_policy::edit_allowed(user, crop.is_reference, crop.user_id))
        .map(|crop| crop.id)
}
