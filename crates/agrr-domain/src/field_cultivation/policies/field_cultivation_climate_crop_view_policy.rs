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
mod tests {
    use super::*;
    use crate::field_cultivation::dtos::ClimateCropEntity;

    fn crop(is_reference: bool, user_id: Option<i64>) -> ClimateCropEntity {
        ClimateCropEntity {
            id: 1,
            is_reference,
            user_id,
            crop_stages: vec![],
        }
    }

    #[test]
    fn public_plan_allows_reference_crop_only() {
        assert!(view_allowed(None, &crop(true, None), true));
        assert!(!view_allowed(None, &crop(false, Some(1)), true));
    }

    #[test]
    fn private_plan_uses_crop_policy() {
        let user = User::new(5, false);
        assert!(view_allowed(Some(&user), &crop(false, Some(5)), false));
        assert!(!view_allowed(Some(&user), &crop(false, Some(99)), false));
    }
}
