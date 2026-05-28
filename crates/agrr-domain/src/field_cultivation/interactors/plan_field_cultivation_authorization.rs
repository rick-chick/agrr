use crate::field_cultivation::gateways::FieldCultivationPlanAccessGateway;
use crate::field_cultivation::policies::{
    assert_edit_allowed, assert_view_allowed,
};
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::user::User;

pub fn assert_field_cultivation_plan_access<G: FieldCultivationPlanAccessGateway + ?Sized>(
    user: &User,
    gateway: &G,
    field_cultivation_id: i64,
    for_edit: bool,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let access_snapshot =
        gateway.find_plan_access_snapshot_by_field_cultivation_id(field_cultivation_id)?;
    if for_edit {
        assert_edit_allowed(user, &access_snapshot)?;
    } else {
        assert_view_allowed(user, &access_snapshot)?;
    }
    Ok(())
}

pub fn assert_public_field_cultivation_plan_access<G: FieldCultivationPlanAccessGateway + ?Sized>(
    gateway: &G,
    field_cultivation_id: i64,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let access_snapshot =
        gateway.find_plan_access_snapshot_by_field_cultivation_id(field_cultivation_id)?;
    if access_snapshot.plan_type_public() {
        Ok(())
    } else {
        Err(Box::new(PolicyPermissionDenied))
    }
}
