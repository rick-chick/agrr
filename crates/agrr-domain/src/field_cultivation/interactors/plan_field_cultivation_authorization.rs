use crate::field_cultivation::dtos::FieldCultivationPlanAccessSnapshot;
use crate::field_cultivation::policies::{assert_edit_allowed, assert_view_allowed};
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::user::User;

pub fn assert_field_cultivation_plan_access(
    user: &User,
    access_snapshot: &FieldCultivationPlanAccessSnapshot,
    for_edit: bool,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if for_edit {
        assert_edit_allowed(user, access_snapshot)?;
    } else {
        assert_view_allowed(user, access_snapshot)?;
    }
    Ok(())
}

pub fn assert_public_field_cultivation_plan_access(
    access_snapshot: &FieldCultivationPlanAccessSnapshot,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if access_snapshot.plan_type_public() {
        Ok(())
    } else {
        Err(Box::new(PolicyPermissionDenied))
    }
}

pub fn assert_public_field_cultivation_mutation_access(
    access_snapshot: &FieldCultivationPlanAccessSnapshot,
    requested_session_id: Option<&str>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    use crate::cultivation_plan::policies::public_plan_session_authorization;

    if !access_snapshot.plan_type_public() {
        return Err(Box::new(PolicyPermissionDenied));
    }
    let session = requested_session_id.unwrap_or_default();
    if !public_plan_session_authorization::session_matches(
        access_snapshot.plan_session_id.as_deref(),
        session,
    ) {
        return Err(Box::new(PolicyPermissionDenied));
    }
    Ok(())
}
