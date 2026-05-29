use crate::field_cultivation::dtos::ClimateCropEntity;
use crate::shared::policies::crop_policy;
use crate::shared::user::User;

pub fn view_allowed(
    user: Option<&User>,
    crop_entity: &ClimateCropEntity,
    plan_type_public: bool,
) -> bool {
    if plan_type_public {
        crop_entity.is_reference
    } else {
        let Some(user) = user else {
            return false;
        };
        crop_policy::view_allowed(user, crop_entity.is_reference, crop_entity.user_id)
    }
}

#[cfg(test)]
mod policies_field_cultivation_climate_crop_view_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/policies_field_cultivation_climate_crop_view_policy_test.rs"));
}
